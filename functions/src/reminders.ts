import type { DocumentData } from "firebase-admin/firestore";

const DAY = 86400000;
/** Tüm gün etkinlikleri için hatırlatma baz saati (yerel 09:00). */
const ALL_DAY_BASE_HOURS = 9;

function addMonths(d: Date, n: number): Date {
  const r = new Date(d.getTime());
  const day = r.getUTCDate();
  r.setUTCDate(1);
  r.setUTCMonth(r.getUTCMonth() + n);
  const last = new Date(Date.UTC(r.getUTCFullYear(), r.getUTCMonth() + 1, 0)).getUTCDate();
  r.setUTCDate(Math.min(day, last));
  return r;
}

/**
 * Etkinliğin `startsAt` (mutlak zaman), `time`, `repeat` ve `reminder`
 * (dakika) alanlarından, [nowMs] sonrasındaki ilk hatırlatma anını hesaplar.
 */
export function computeNextReminder(e: DocumentData, nowMs: number): Date | null {
  const reminder = e.reminder;
  if (reminder === null || reminder === undefined) return null;
  const startsAt: Date | undefined = e.startsAt?.toDate?.();
  if (!startsAt) return null;
  const base = e.time ? startsAt : new Date(startsAt.getTime() + ALL_DAY_BASE_HOURS * 3600000);
  const offset = Number(reminder) * 60000;
  const repeat = String(e.repeat ?? "none");

  let occurrence = base;
  for (let i = 0; i < 2000; i++) {
    if (occurrence.getTime() - offset > nowMs) return new Date(occurrence.getTime() - offset);
    switch (repeat) {
      case "daily":
        occurrence = new Date(occurrence.getTime() + DAY);
        break;
      case "weekly":
        occurrence = new Date(occurrence.getTime() + 7 * DAY);
        break;
      case "monthly":
        occurrence = addMonths(base, i + 1);
        break;
      case "yearly":
        occurrence = addMonths(base, 12 * (i + 1));
        break;
      default:
        return null;
    }
  }
  return null;
}

export function reminderLabel(minutes: number): string {
  if (minutes <= 0) return "Şimdi";
  if (minutes < 60) return `${minutes} dakika sonra`;
  if (minutes < 1440) return `${Math.round(minutes / 60)} saat sonra`;
  if (minutes < 10080) return `${Math.round(minutes / 1440)} gün sonra`;
  return "1 hafta sonra";
}
