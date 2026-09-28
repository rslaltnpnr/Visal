import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";

import { bucket, db, deletePrefix, firstName, getCouple, getUser, partnerOf, Timestamp } from "./common";
import { notifyUser } from "./notify";
import { computeNextReminder } from "./reminders";

const LOVE_TEXT: Record<string, string> = {
  love: "seni düşünüyor.",
  miss: "seni özledi.",
  kiss: "sana bir öpücük gönderdi.",
  home: "eve geliyor.",
  coffee: "kahve içmek istiyor.",
  call: "müsait misin diye soruyor.",
};

function messagePreview(m: FirebaseFirestore.DocumentData): string {
  switch (m.type) {
    case "text":
      return String(m.text ?? "").slice(0, 180);
    case "image":
      return "📷 Fotoğraf";
    case "video":
      return "🎬 Video";
    case "voice":
      return "🎤 Sesli mesaj";
    case "file":
      return `📎 ${m.media?.name ?? "Dosya"}`;
    case "gif":
      return "GIF";
    default:
      return "Yeni mesaj";
  }
}

/** Yeni mesaj → partnere push. Hızlı sevgi mesajları özel metinle gider. */
export const onMessageCreated = onDocumentCreated("couples/{coupleId}/messages/{messageId}", async (event) => {
  const m = event.data?.data();
  if (!m) return;
  const couple = await getCouple(event.params.coupleId);
  if (!couple || couple.status === "archived") return;
  const to = partnerOf(couple, m.senderId);
  if (!to) return;
  const sender = await getUser(m.senderId);
  const name = firstName(sender?.name);

  if (m.type === "love") {
    const kind = String(m.loveKind ?? "love");
    await notifyUser(to, {
      category: "love",
      type: "love",
      title: "VISAL",
      body: `${String(m.text ?? "❤️").split(" ")[0]} ${name} ${LOVE_TEXT[kind] ?? LOVE_TEXT.love}`,
      hiddenBody: "Yeni mesaj",
      route: "/chat",
      collapseKey: "chat",
    });
    return;
  }

  await notifyUser(to, {
    category: "messages",
    type: "message",
    title: name,
    body: messagePreview(m),
    hiddenBody: "Yeni mesaj",
    route: "/chat",
    collapseKey: "chat",
  });
});

/** "Herkesten sil" → medya dosyası da silinir. */
export const onMessageUpdated = onDocumentUpdated("couples/{coupleId}/messages/{messageId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (!before.deletedForAll && after.deletedForAll) {
    await deletePrefix(`couples/${event.params.coupleId}/chat/${event.params.messageId}/`);
  }
});

export const onMemoryCreated = onDocumentCreated("couples/{coupleId}/memories/{memoryId}", async (event) => {
  const m = event.data?.data();
  if (!m) return;
  const couple = await getCouple(event.params.coupleId);
  if (!couple || couple.status === "archived") return;
  const to = partnerOf(couple, m.createdBy);
  if (!to) return;
  const sender = await getUser(m.createdBy);
  await notifyUser(to, {
    category: "memories",
    type: "memory",
    title: "Yeni anı ✨",
    body: `${firstName(sender?.name)} bir anı ekledi: ${String(m.title ?? "").slice(0, 80)}`,
    hiddenBody: "Yeni bir anı eklendi",
    route: `/memory/${event.params.memoryId}`,
    inbox: true,
  });
});

export const onMemoryDeleted = onDocumentDeleted("couples/{coupleId}/memories/{memoryId}", async (event) => {
  await deletePrefix(`couples/${event.params.coupleId}/memories/${event.params.memoryId}/`);
});

export const onTimelineDeleted = onDocumentDeleted("couples/{coupleId}/timeline/{eventId}", async (event) => {
  await deletePrefix(`couples/${event.params.coupleId}/timeline/${event.params.eventId}/`);
});

export const onCapsuleCreated = onDocumentCreated("couples/{coupleId}/capsules/{capsuleId}", async (event) => {
  const c = event.data?.data();
  if (!c) return;
  const sender = await getUser(c.createdBy);
  const openAt = (c.openAt as Timestamp).toDate();
  const date = new Intl.DateTimeFormat("tr-TR", { dateStyle: "long", timeZone: "Europe/Istanbul" }).format(openAt);
  await notifyUser(c.recipientId, {
    category: "capsules",
    type: "capsule",
    title: "Sana bir kapsül bırakıldı ⏳",
    body: `${firstName(sender?.name)} sana bir anı kapsülü bıraktı. ${date} tarihinde açılacak.`,
    hiddenBody: "Yeni bir kapsül",
    route: `/capsule/${event.params.capsuleId}`,
    inbox: true,
  });
});

export const onCapsuleDeleted = onDocumentDeleted("couples/{coupleId}/capsules/{capsuleId}", async (event) => {
  const { coupleId, capsuleId } = event.params;
  await db.recursiveDelete(db.collection(`couples/${coupleId}/capsules/${capsuleId}/content`));
  await deletePrefix(`couples/${coupleId}/capsules/${capsuleId}/`);
});

/** Etkinlik yazıldığında bir sonraki hatırlatma zamanını hesaplar. */
export const onEventWritten = onDocumentWritten("couples/{coupleId}/events/{eventId}", async (event) => {
  const after = event.data?.after;
  if (!after?.exists) return;
  const data = after.data()!;
  const next = computeNextReminder(data, Date.now());
  const current = (data.nextReminderAt as Timestamp | null | undefined)?.toMillis() ?? null;
  const nextMs = next?.getTime() ?? null;
  if (current === nextMs) return;
  await after.ref.update({ nextReminderAt: next ? Timestamp.fromDate(next) : null });
});

/** Kullanıcı avatarı değişince eski dosyaları temizle (en son 3'ü tut). */
export const onUserUpdated = onDocumentUpdated("users/{uid}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before.photoUrl === after.photoUrl) return;
  const [files] = await bucket().getFiles({ prefix: `users/${event.params.uid}/avatar/` });
  const sorted = files.sort(
    (a, b) => new Date(b.metadata.timeCreated ?? 0).getTime() - new Date(a.metadata.timeCreated ?? 0).getTime(),
  );
  await Promise.all(sorted.slice(6).map((f) => f.delete().catch(() => undefined)));
});
