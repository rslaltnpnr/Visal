import { randomInt } from "node:crypto";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE, db, FieldValue, firstName, getUser, partnerOf, requireAuth, rtdb, Timestamp, type CoupleDoc } from "./common";
import { notifyUser } from "./notify";

// Karışabilecek karakterler (I, O, 0, 1) çıkarıldı.
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_RE = /^VISAL-[A-HJ-NP-Z2-9]{5}$/;
const INVITE_TTL_MS = 24 * 60 * 60 * 1000;
const ARCHIVE_RETENTION_DAYS = 30;

function generateCode(): string {
  let s = "";
  for (let i = 0; i < 5; i++) s += ALPHABET[randomInt(ALPHABET.length)];
  return `VISAL-${s}`;
}

/** Davet kodu oluşturur. Kullanıcının önceki kodları geçersiz olur. */
export const createInvite = onCall(CALLABLE, async (req) => {
  const uid = requireAuth(req);
  const user = await getUser(uid);
  if (!user) throw new HttpsError("failed-precondition", "Profil bulunamadı.");
  if (user.coupleId) throw new HttpsError("failed-precondition", "Zaten bir partnerle eşleşmişsiniz.");

  const old = await db.collection("invites").where("uid", "==", uid).get();
  const batch = db.batch();
  old.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();

  const expiresAt = Date.now() + INVITE_TTL_MS;
  for (let attempt = 0; attempt < 8; attempt++) {
    const code = generateCode();
    try {
      await db.doc(`invites/${code}`).create({
        uid,
        used: false,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(expiresAt),
      });
      return { code, expiresAt };
    } catch {
      // Çakışma: yeni kod dene.
    }
  }
  throw new HttpsError("resource-exhausted", "Kod oluşturulamadı, tekrar deneyin.");
});

/** Partnerin kodunu girerek eşleşme isteği gönderir. */
export const requestPairing = onCall<{ code?: string }>(CALLABLE, async (req) => {
  const uid = requireAuth(req);
  const code = String(req.data?.code ?? "").trim().toUpperCase();
  if (!CODE_RE.test(code)) throw new HttpsError("invalid-argument", "Kod geçersiz.");

  const inviteSnap = await db.doc(`invites/${code}`).get();
  const invite = inviteSnap.data();
  if (!invite || invite.used || (invite.expiresAt as Timestamp).toMillis() < Date.now()) {
    throw new HttpsError("not-found", "Bu kod geçersiz veya süresi dolmuş.");
  }
  const inviterId = invite.uid as string;
  if (inviterId === uid) throw new HttpsError("invalid-argument", "Kendi kodunuzu giremezsiniz.");

  const [me, inviter] = await Promise.all([getUser(uid), getUser(inviterId)]);
  if (!me || !inviter) throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
  if (me.coupleId) throw new HttpsError("failed-precondition", "Zaten bir partnerle eşleşmişsiniz.");
  if (inviter.coupleId) throw new HttpsError("failed-precondition", "Bu kullanıcı başka biriyle eşleşmiş.");

  // Aynı kişiye bekleyen isteği tekrar gönderme.
  const pending = await db
    .collection("pairRequests")
    .where("fromUid", "==", uid)
    .where("status", "==", "pending")
    .get();
  const batch = db.batch();
  pending.docs.forEach((d) => batch.update(d.ref, { status: "cancelled", updatedAt: FieldValue.serverTimestamp() }));

  const ref = db.collection("pairRequests").doc();
  batch.set(ref, {
    fromUid: uid,
    fromName: me.name,
    fromPhoto: me.photoUrl ?? null,
    toUid: inviterId,
    toName: inviter.name,
    code,
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();

  await notifyUser(inviterId, {
    category: "pairing",
    type: "pairing",
    title: "Eşleşme isteği",
    body: `${firstName(me.name)} sizinle VISAL'da eşleşmek istiyor.`,
    hiddenBody: "Yeni bir eşleşme isteği",
    route: `/pairing/request/${ref.id}`,
    inbox: true,
  });

  return { requestId: ref.id, inviterName: inviter.name };
});

/** Davet sahibi isteği kabul eder / reddeder. */
export const respondPairing = onCall<{ requestId?: string; accept?: boolean }>(
  CALLABLE,
  async (req) => {
    const uid = requireAuth(req);
    const requestId = String(req.data?.requestId ?? "");
    const accept = req.data?.accept === true;
    if (!requestId) throw new HttpsError("invalid-argument", "İstek bulunamadı.");

    const reqRef = db.doc(`pairRequests/${requestId}`);

    if (!accept) {
      const snap = await reqRef.get();
      const r = snap.data();
      if (!r || r.toUid !== uid) throw new HttpsError("permission-denied", "Bu istek size ait değil.");
      if (r.status !== "pending") return { ok: true };
      await reqRef.update({ status: "rejected", updatedAt: FieldValue.serverTimestamp() });
      await notifyUser(r.fromUid, {
        category: "pairing",
        type: "pairing",
        title: "Eşleşme isteği",
        body: `${firstName(r.toName)} isteğinizi kabul etmedi.`,
        route: "/pairing",
        inbox: true,
      });
      return { ok: true };
    }

    const coupleRef = db.collection("couples").doc();
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(reqRef);
      const r = snap.data();
      if (!r || r.toUid !== uid) throw new HttpsError("permission-denied", "Bu istek size ait değil.");
      if (r.status !== "pending") throw new HttpsError("failed-precondition", "Bu istek artık geçerli değil.");

      const fromUid = r.fromUid as string;
      const toRef = db.doc(`users/${uid}`);
      const fromRef = db.doc(`users/${fromUid}`);
      const [toSnap, fromSnap] = await Promise.all([tx.get(toRef), tx.get(fromRef)]);
      const to = toSnap.data();
      const from = fromSnap.data();
      if (!to || !from) throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
      if (to.coupleId || from.coupleId) {
        tx.update(reqRef, { status: "expired", updatedAt: FieldValue.serverTimestamp() });
        throw new HttpsError("failed-precondition", "Taraflardan biri zaten eşleşmiş.");
      }

      tx.set(coupleRef, {
        members: [uid, fromUid],
        status: "active",
        relationshipStartDate: null,
        anniversaryDate: null,
        theme: "default",
        coverPhoto: null,
        createdAt: FieldValue.serverTimestamp(),
      });
      for (const [id, u] of [
        [uid, to],
        [fromUid, from],
      ] as const) {
        tx.set(coupleRef.collection("profiles").doc(id), {
          name: u.name ?? "",
          photoUrl: u.photoUrl ?? null,
          birthday: u.birthday ?? null,
          moodVisible: u.settings?.privacy?.moodVisible ?? true,
        });
      }
      tx.update(toRef, { coupleId: coupleRef.id });
      tx.update(fromRef, { coupleId: coupleRef.id });
      tx.update(reqRef, { status: "accepted", coupleId: coupleRef.id, updatedAt: FieldValue.serverTimestamp() });
      tx.set(db.doc(`invites/${r.code}`), { used: true }, { merge: true });
      return { fromUid, toName: to.name as string };
    });

    // Realtime Database presence kuralları için eşleşme eşlemesi.
    await rtdb.ref().update({
      [`userCouples/${uid}`]: coupleRef.id,
      [`userCouples/${result.fromUid}`]: coupleRef.id,
    });

    // Taraflarla ilgili diğer bekleyen istekleri geçersiz kıl.
    const others = await Promise.all([
      db.collection("pairRequests").where("toUid", "in", [uid, result.fromUid]).where("status", "==", "pending").get(),
      db.collection("pairRequests").where("fromUid", "in", [uid, result.fromUid]).where("status", "==", "pending").get(),
    ]);
    const batch = db.batch();
    others.flatMap((s) => s.docs).forEach((d) => batch.update(d.ref, { status: "expired" }));
    await batch.commit();

    await notifyUser(result.fromUid, {
      category: "pairing",
      type: "pairing",
      title: "Artık burası ikinize ait 💞",
      body: `${firstName(result.toName)} eşleşme isteğinizi kabul etti.`,
      route: "/home",
      inbox: true,
    });

    return { coupleId: coupleRef.id };
  },
);

export const cancelPairing = onCall<{ requestId?: string }>(CALLABLE, async (req) => {
  const uid = requireAuth(req);
  const ref = db.doc(`pairRequests/${String(req.data?.requestId ?? "")}`);
  const snap = await ref.get();
  const r = snap.data();
  if (!r || r.fromUid !== uid) throw new HttpsError("permission-denied", "Bu istek size ait değil.");
  if (r.status === "pending") {
    await ref.update({ status: "cancelled", updatedAt: FieldValue.serverTimestamp() });
  }
  return { ok: true };
});

/**
 * Eşleşmeyi sonlandırır: çift alanı arşivlenir (erişim kapanır) ve
 * 30 gün sonra zamanlanmış görevle kalıcı olarak silinir.
 */
export async function dissolveCouple(coupleId: string, byUid: string, notify = true): Promise<void> {
  const coupleRef = db.doc(`couples/${coupleId}`);
  const snap = await coupleRef.get();
  const couple = snap.data() as CoupleDoc | undefined;
  if (!couple) return;
  const partnerId = partnerOf(couple, byUid);

  const batch = db.batch();
  batch.update(coupleRef, {
    status: "archived",
    archivedAt: FieldValue.serverTimestamp(),
    archivedBy: byUid,
    purgeAt: Timestamp.fromMillis(Date.now() + ARCHIVE_RETENTION_DAYS * 86400000),
  });
  for (const m of couple.members) {
    batch.set(db.doc(`users/${m}`), { coupleId: null }, { merge: true });
  }
  await batch.commit();

  const updates: Record<string, null> = {};
  couple.members.forEach((m) => (updates[`userCouples/${m}`] = null));
  await rtdb.ref().update(updates);

  if (notify && partnerId) {
    const me = await getUser(byUid);
    await notifyUser(partnerId, {
      category: "pairing",
      type: "pairing",
      title: "Eşleşme sona erdi",
      body: `${firstName(me?.name)} ortak alanınızı kapattı.`,
      route: "/pairing",
      inbox: true,
    });
  }
}

export const unpair = onCall(CALLABLE, async (req) => {
  const uid = requireAuth(req);
  const user = await getUser(uid);
  if (!user?.coupleId) throw new HttpsError("failed-precondition", "Eşleşme bulunamadı.");
  await dissolveCouple(user.coupleId, uid);
  return { ok: true };
});
