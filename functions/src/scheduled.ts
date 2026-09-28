import { onSchedule } from "firebase-functions/v2/scheduler";

import { purgeCouple } from "./account";
import { db, firstName, istanbulMonthDay, TIMEZONE, Timestamp, type CoupleDoc } from "./common";
import { notifyUser } from "./notify";
import { computeNextReminder, reminderLabel } from "./reminders";

/** Her 5 dakikada: açılma zamanı gelen kapsüller + etkinlik hatırlatmaları. */
export const tickFiveMinutes = onSchedule(
  { schedule: "every 5 minutes", timeZone: TIMEZONE, timeoutSeconds: 300 },
  async () => {
    const now = Timestamp.now();

    // --- Kapsüller ---
    const capsules = await db
      .collectionGroup("capsules")
      .where("notified", "==", false)
      .where("openAt", "<=", now)
      .limit(300)
      .get();
    for (const doc of capsules.docs) {
      const c = doc.data();
      const coupleId = doc.ref.parent.parent?.id;
      const couple = coupleId ? await getActiveCouple(coupleId) : null;
      await doc.ref.update({ notified: true, openedAt: now });
      if (!couple) continue;
      await notifyUser(c.recipientId, {
        category: "capsules",
        type: "capsule",
        title: "Kapsül açıldı 🔓",
        body: "Partnerinin sana bıraktığı bir kapsül açıldı.",
        hiddenBody: "Bir kapsül açıldı",
        route: `/capsule/${doc.id}`,
        inbox: true,
      });
    }

    // --- Etkinlik hatırlatmaları ---
    const events = await db.collectionGroup("events").where("nextReminderAt", "<=", now).limit(300).get();
    for (const doc of events.docs) {
      const e = doc.data();
      const coupleId = doc.ref.parent.parent?.id;
      const couple = coupleId ? await getActiveCouple(coupleId) : null;
      const next = computeNextReminder(e, Date.now() + 60000);
      await doc.ref.update({ nextReminderAt: next ? Timestamp.fromDate(next) : null });
      if (!couple) continue;
      const when = e.time ? `${reminderLabel(Number(e.reminder))} · ${e.time}` : reminderLabel(Number(e.reminder));
      await Promise.all(
        couple.members.map((uid) =>
          notifyUser(uid, {
            category: "events",
            type: "event",
            title: `⏰ ${String(e.title ?? "Plan")}`,
            body: e.location ? `${when} · ${e.location}` : when,
            hiddenBody: "Yaklaşan bir planınız var",
            route: `/event/${doc.id}`,
            inbox: true,
          }),
        ),
      );
    }
  },
);

/** Her sabah 09:00: yaklaşan özel günler ve günün sorusu. */
export const dailyMorning = onSchedule(
  { schedule: "0 9 * * *", timeZone: TIMEZONE, timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const now = new Date();
    let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    for (;;) {
      let q = db.collection("couples").where("status", "==", "active").orderBy("__name__").limit(300);
      if (last) q = q.startAfter(last);
      const page = await q.get();
      if (page.empty) break;
      for (const doc of page.docs) {
        await handleCoupleMorning(doc.id, doc.data() as CoupleDoc, now).catch((e) =>
          console.error("dailyMorning couple failed", doc.id, e),
        );
      }
      last = page.docs[page.docs.length - 1];
      if (page.size < 300) break;
    }
  },
);

async function handleCoupleMorning(coupleId: string, couple: CoupleDoc, now: Date): Promise<void> {
  const today = istanbulMonthDay(now);
  const special: { title: string; body: (days: number) => string; date: Date; for?: string[] }[] = [];

  const anniversary = (couple.anniversaryDate ?? couple.relationshipStartDate)?.toDate();
  if (anniversary) {
    special.push({
      title: "Yıldönümü 💍",
      date: anniversary,
      body: (d) => (d === 0 ? "Bugün sizin gününüz. Mutlu yıldönümü! ❤️" : `Yıldönümünüze ${d} gün kaldı.`),
    });
  }
  const profiles = await db.collection(`couples/${coupleId}/profiles`).get();
  for (const p of profiles.docs) {
    const b = (p.get("birthday") as Timestamp | null)?.toDate();
    if (!b) continue;
    const name = firstName(p.get("name"));
    const partner = couple.members.find((m) => m !== p.id);
    special.push({
      title: "Doğum günü 🎂",
      date: b,
      for: partner ? [partner] : [],
      body: (d) => (d === 0 ? `Bugün ${name}'in doğum günü! 🎉` : `${name}'in doğum gününe ${d} gün kaldı.`),
    });
  }

  for (const s of special) {
    const d = daysUntilYearly(s.date, today, now);
    if (d !== 0 && d !== 1 && d !== 7) continue;
    for (const uid of s.for ?? couple.members) {
      await notifyUser(uid, {
        category: "events",
        type: "event",
        title: s.title,
        body: s.body(d),
        route: "/plans",
        inbox: true,
      });
    }
  }

  for (const uid of couple.members) {
    await notifyUser(uid, {
      category: "dailyQuestion",
      type: "question",
      title: "Bugünün sorusu hazır ✨",
      body: "Cevabını paylaş; ikiniz de cevaplayınca cevaplar açılsın.",
      route: "/questions",
    });
  }
}

function daysUntilYearly(date: Date, today: { month: number; day: number }, now: Date): number {
  const { month, day } = istanbulMonthDay(date);
  const year = Number(new Intl.DateTimeFormat("en", { timeZone: TIMEZONE, year: "numeric" }).format(now));
  const t = Date.UTC(year, today.month - 1, today.day);
  let target = Date.UTC(year, month - 1, day);
  if (target < t) target = Date.UTC(year + 1, month - 1, day);
  return Math.round((target - t) / 86400000);
}

/** Her gece: süresi dolan arşivlenmiş çift alanlarını kalıcı sil. */
export const purgeArchivedCouples = onSchedule(
  { schedule: "30 3 * * *", timeZone: TIMEZONE, timeoutSeconds: 540, memory: "1GiB" },
  async () => {
    const due = await db
      .collection("couples")
      .where("status", "==", "archived")
      .where("purgeAt", "<=", Timestamp.now())
      .limit(50)
      .get();
    for (const doc of due.docs) {
      await purgeCouple(doc.id);
    }
    // Süresi geçmiş davet kodları
    const invites = await db.collection("invites").where("expiresAt", "<=", Timestamp.now()).limit(500).get();
    const batch = db.batch();
    invites.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  },
);

async function getActiveCouple(coupleId: string): Promise<CoupleDoc | null> {
  const snap = await db.doc(`couples/${coupleId}`).get();
  const c = snap.data() as CoupleDoc | undefined;
  return c && c.status !== "archived" ? c : null;
}
