import { db, FieldValue, getUser, messaging } from "./common";

/** Kullanıcı ayarlarındaki bildirim kategorileri. */
export type NotifyCategory =
  | "messages"
  | "love"
  | "memories"
  | "capsules"
  | "events"
  | "dailyQuestion"
  | "pairing";

export type NotifyType =
  | "message"
  | "love"
  | "memory"
  | "capsule"
  | "event"
  | "question"
  | "pairing";

export interface NotifyPayload {
  category: NotifyCategory;
  type: NotifyType;
  title: string;
  body: string;
  /** Uygulama içi rota (bildirime dokunulunca açılır). */
  route: string;
  /** Gizli modda gösterilecek metin. */
  hiddenBody?: string;
  /** users/{uid}/inbox'a da yazılsın mı? */
  inbox?: boolean;
  /** Aynı türden bildirimleri gruplamak için. */
  collapseKey?: string;
}

const CHANNELS: Record<NotifyType, string> = {
  message: "visal_messages",
  love: "visal_messages",
  memory: "visal_moments",
  capsule: "visal_moments",
  question: "visal_moments",
  pairing: "visal_moments",
  event: "visal_reminders",
};

/**
 * Tek bir kullanıcıya push bildirim gönderir.
 * - Kullanıcının kategori tercihlerini uygular.
 * - Bildirim gizli modundaysa içerik yerine "VISAL — Yeni mesaj" gösterilir.
 * - Geçersiz FCM jetonlarını temizler.
 */
export async function notifyUser(uid: string, p: NotifyPayload): Promise<void> {
  const user = await getUser(uid);
  if (!user) return;

  if (p.inbox) {
    await db.collection(`users/${uid}/inbox`).add({
      type: p.type,
      title: p.title,
      body: p.body,
      route: p.route,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  const prefs = user.settings?.notifications ?? {};
  if (p.category !== "pairing" && prefs[p.category] === false) return;

  const hidden = user.settings?.privacy?.notificationPreview === false;
  const title = hidden ? "VISAL" : p.title;
  const body = hidden ? (p.hiddenBody ?? "Yeni bildirim") : p.body;

  const tokensSnap = await db.collection(`users/${uid}/tokens`).get();
  const tokens = tokensSnap.docs.map((d) => d.id);
  if (tokens.length === 0) return;

  const res = await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: { type: p.type, route: p.route },
    android: {
      priority: "high",
      collapseKey: p.collapseKey,
      notification: {
        channelId: CHANNELS[p.type],
        color: "#B68AA0",
        tag: p.collapseKey,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          threadId: p.collapseKey ?? p.type,
        },
      },
    },
  });

  const invalid: string[] = [];
  res.responses.forEach((r, i) => {
    const code = r.error?.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument"
    ) {
      invalid.push(tokens[i]);
    }
  });
  await Promise.all(invalid.map((t) => db.doc(`users/${uid}/tokens/${t}`).delete()));
}
