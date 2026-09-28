import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  auth,
  CALLABLE,
  db,
  deletePrefix,
  getCouple,
  getUser,
  partnerOf,
  recursiveDelete,
  requireAuth,
  rtdb,
} from "./common";
import { notifyUser } from "./notify";

const MAX_EXPORT_MESSAGES = 20000;

type Json = Record<string, unknown>;

function serialize(value: unknown): unknown {
  if (value === null || value === undefined) return value ?? null;
  if (typeof value === "object") {
    const v = value as { toDate?: () => Date; latitude?: number };
    if (typeof v.toDate === "function") return v.toDate().toISOString();
    if (Array.isArray(value)) return value.map(serialize);
    const out: Json = {};
    for (const [k, val] of Object.entries(value as Json)) out[k] = serialize(val);
    return out;
  }
  return value;
}

async function collectionDump(path: string, limit = 5000, filter?: (d: Json) => boolean): Promise<Json[]> {
  const snap = await db.collection(path).limit(limit).get();
  return snap.docs
    .map((d) => ({ id: d.id, ...(d.data() as Json) }))
    .filter((d) => (filter ? filter(d) : true))
    .map((d) => serialize(d) as Json);
}

/**
 * KVKK/GDPR veri taşınabilirliği: kullanıcının kendi verisi ve erişebildiği
 * ortak alan içeriği JSON olarak döner. Medya dosyaları bağlantı olarak yer alır.
 */
export const exportUserData = onCall({ ...CALLABLE, timeoutSeconds: 300, memory: "1GiB" }, async (req) => {
  const uid = requireAuth(req);
  const userSnap = await db.doc(`users/${uid}`).get();
  if (!userSnap.exists) throw new HttpsError("not-found", "Profil bulunamadı.");
  const result: Json = {
    exportedAt: new Date().toISOString(),
    app: "VISAL",
    user: serialize({ id: uid, ...userSnap.data() }),
  };

  const coupleId = userSnap.get("coupleId") as string | null;
  if (coupleId) {
    const base = `couples/${coupleId}`;
    const couple = await getCouple(coupleId);
    const now = Date.now();
    result.couple = serialize({ id: coupleId, ...couple });
    result.messages = await collectionDump(
      `${base}/messages`,
      MAX_EXPORT_MESSAGES,
      (m) => !((m.deletedFor as string[] | undefined) ?? []).includes(uid),
    );
    result.memories = await collectionDump(`${base}/memories`);
    result.timeline = await collectionDump(`${base}/timeline`);
    result.events = await collectionDump(`${base}/events`);
    result.tasks = await collectionDump(`${base}/tasks`);
    result.goals = await collectionDump(`${base}/goals`);
    result.questions = await collectionDump(`${base}/questions`);
    result.answers = await collectionDump(`${base}/answers`, 5000, (a) => a.uid === uid);
    result.moods = await collectionDump(`${base}/moods`, 5000, (m) => m.uid === uid);

    const capsules = await db.collection(`${base}/capsules`).get();
    const visible = [];
    for (const c of capsules.docs) {
      const data = c.data();
      const opened = data.openAt?.toMillis?.() <= now;
      if (data.createdBy !== uid && !opened) continue;
      const content = await c.ref.collection("content").doc("main").get();
      visible.push(serialize({ id: c.id, ...data, content: content.data() ?? null }));
    }
    result.capsules = visible;
  }
  return result;
});

/**
 * Hesabı kalıcı olarak siler. Ortak alan (çift) varsa tüm içeriğiyle birlikte
 * silinir ve partnerin eşleşmesi kaldırılır.
 */
export const deleteAccount = onCall({ ...CALLABLE, timeoutSeconds: 540, memory: "1GiB" }, async (req) => {
  const uid = requireAuth(req);
  const user = await getUser(uid);

  if (user?.coupleId) {
    const couple = await getCouple(user.coupleId);
    const partnerId = couple ? partnerOf(couple, uid) : undefined;
    await purgeCouple(user.coupleId);
    if (partnerId) {
      await db.doc(`users/${partnerId}`).set({ coupleId: null }, { merge: true });
      await rtdb.ref(`userCouples/${partnerId}`).remove();
      await notifyUser(partnerId, {
        category: "pairing",
        type: "pairing",
        title: "Eşleşme sona erdi",
        body: "Partnerin VISAL hesabını sildi. Ortak alanınız kapatıldı.",
        route: "/pairing",
        inbox: true,
      });
    }
  }

  const [invites, fromReqs, toReqs] = await Promise.all([
    db.collection("invites").where("uid", "==", uid).get(),
    db.collection("pairRequests").where("fromUid", "==", uid).get(),
    db.collection("pairRequests").where("toUid", "==", uid).get(),
  ]);
  const batch = db.batch();
  [...invites.docs, ...fromReqs.docs, ...toReqs.docs].forEach((d) => batch.delete(d.ref));
  await batch.commit();

  await deletePrefix(`users/${uid}/`);
  await recursiveDelete(`users/${uid}`);
  await rtdb.ref().update({ [`presence/${uid}`]: null, [`userCouples/${uid}`]: null });
  await auth.deleteUser(uid);
  return { ok: true };
});

/** Çift belgesini, tüm alt koleksiyonları ve Storage dosyalarını siler. */
export async function purgeCouple(coupleId: string): Promise<void> {
  await deletePrefix(`couples/${coupleId}/`);
  await recursiveDelete(`couples/${coupleId}`);
}
