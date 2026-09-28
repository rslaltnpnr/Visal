import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getDatabase } from "firebase-admin/database";
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getStorage } from "firebase-admin/storage";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, type CallableRequest } from "firebase-functions/v2/https";

initializeApp();

/** İstemcideki `kFunctionsRegion` ile aynı olmalı. */
export const REGION = "europe-west1";
export const TIMEZONE = "Europe/Istanbul";

setGlobalOptions({ region: REGION, maxInstances: 20 });

/**
 * Callable fonksiyon seçenekleri. App Check üretimde zorunludur; yerel
 * geliştirme için `functions/.env.local` içinde ENFORCE_APP_CHECK=false
 * verilebilir.
 */
export const CALLABLE = {
  enforceAppCheck: process.env.ENFORCE_APP_CHECK !== "false",
  cors: false,
};

export const db = getFirestore();
db.settings({ ignoreUndefinedProperties: true });
export const auth = getAuth();
export const rtdb = getDatabase();
export const messaging = getMessaging();
export const bucket = () => getStorage().bucket();
export { FieldValue, Timestamp };

export interface UserDoc {
  uid: string;
  name: string;
  email?: string;
  photoUrl?: string | null;
  coupleId?: string | null;
  birthday?: Timestamp | null;
  settings?: {
    privacy?: { notificationPreview?: boolean };
    notifications?: Record<string, boolean>;
  };
}

export interface CoupleDoc {
  members: string[];
  status?: "active" | "archived";
  relationshipStartDate?: Timestamp | null;
  anniversaryDate?: Timestamp | null;
}

export function requireAuth(req: CallableRequest<unknown>): string {
  if (!req.auth) throw new HttpsError("unauthenticated", "Giriş yapmalısınız.");
  return req.auth.uid;
}

export async function getUser(uid: string): Promise<UserDoc | null> {
  const snap = await db.doc(`users/${uid}`).get();
  return snap.exists ? (snap.data() as UserDoc) : null;
}

export async function getCouple(coupleId: string): Promise<CoupleDoc | null> {
  const snap = await db.doc(`couples/${coupleId}`).get();
  return snap.exists ? (snap.data() as CoupleDoc) : null;
}

export function partnerOf(couple: CoupleDoc, uid: string): string | undefined {
  return couple.members.find((m) => m !== uid);
}

export function firstName(name?: string | null): string {
  return (name ?? "").trim().split(/\s+/)[0] || "Partnerin";
}

/** Bir Storage önekindeki tüm dosyaları siler. */
export async function deletePrefix(prefix: string): Promise<void> {
  try {
    await bucket().deleteFiles({ prefix, force: true });
  } catch (e) {
    console.warn("deletePrefix failed", prefix, e);
  }
}

/** Belgeyi ve tüm alt koleksiyonlarını siler. */
export async function recursiveDelete(path: string): Promise<void> {
  await db.recursiveDelete(db.doc(path));
}

/** yyyy-MM-dd (İstanbul saatine göre). */
export function istanbulDayKey(d = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: TIMEZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(d);
}

export function istanbulMonthDay(d: Date): { month: number; day: number } {
  const [, m, day] = istanbulDayKey(d).split("-").map(Number);
  return { month: m, day };
}
