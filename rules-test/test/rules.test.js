// VISAL güvenlik kuralı testleri (Firestore + Storage emülatörü)
//   cd rules-test && npm install && npm test
import { after, before, beforeEach, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayUnion,
  doc,
  getDoc,
  getDocs,
  collection,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import { getBytes, ref, uploadBytes } from 'firebase/storage';

let env;
const C = 'couple1';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-visal',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
    storage: { rules: readFileSync('../storage.rules', 'utf8') },
  });
});

after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/ayse'), { uid: 'ayse', name: 'Ayşe', coupleId: C });
    await setDoc(doc(db, 'users/resul'), { uid: 'resul', name: 'Resul', coupleId: C });
    await setDoc(doc(db, 'users/mallory'), { uid: 'mallory', name: 'M', coupleId: null });
    await setDoc(doc(db, `couples/${C}`), { members: ['ayse', 'resul'], status: 'active' });
    await setDoc(doc(db, `couples/${C}/profiles/ayse`), { name: 'Ayşe', moodVisible: false });
    await setDoc(doc(db, `couples/${C}/profiles/resul`), { name: 'Resul', moodVisible: true });
    await setDoc(doc(db, `couples/${C}/messages/m1`), {
      senderId: 'ayse', type: 'text', text: 'Merhaba', seenBy: ['ayse'], deletedFor: [], reactions: {}, pinned: false,
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, `couples/${C}/questions/b_1`), { text: 'Soru?', answeredBy: ['ayse'], category: 'fun' });
    await setDoc(doc(db, `couples/${C}/answers/b_1_ayse`), { uid: 'ayse', questionId: 'b_1', text: 'Gizli cevap' });
    await setDoc(doc(db, `couples/${C}/capsules/cap1`), {
      createdBy: 'ayse', recipientId: 'resul', openAt: Timestamp.fromMillis(Date.now() + 86400000), notified: false,
    });
    await setDoc(doc(db, `couples/${C}/capsules/cap1/content/main`), { message: 'Gelecekteki sana', media: [] });
  });
});

const db = (uid) => env.authenticatedContext(uid).firestore();

describe('users', () => {
  it('kendi belgesini okur, başkasınınkini okuyamaz', async () => {
    await assertSucceeds(getDoc(doc(db('ayse'), 'users/ayse')));
    await assertFails(getDoc(doc(db('ayse'), 'users/resul')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'users/ayse')));
  });

  it('coupleId istemciden değiştirilemez', async () => {
    await assertFails(updateDoc(doc(db('mallory'), 'users/mallory'), { coupleId: C }));
    await assertSucceeds(updateDoc(doc(db('mallory'), 'users/mallory'), { name: 'Mal' }));
  });

  it('coupleId dolu olarak kullanıcı oluşturulamaz', async () => {
    await assertFails(setDoc(doc(db('eve'), 'users/eve'), { uid: 'eve', name: 'Eve', coupleId: C }));
    await assertSucceeds(setDoc(doc(db('eve'), 'users/eve'), { uid: 'eve', name: 'Eve', coupleId: null, email: '' }));
  });
});

describe('couples', () => {
  it('coupleId bilinse bile üçüncü kişi erişemez', async () => {
    await assertFails(getDoc(doc(db('mallory'), `couples/${C}`)));
    await assertFails(getDocs(collection(db('mallory'), `couples/${C}/messages`)));
    await assertFails(getDoc(doc(db('mallory'), `couples/${C}/profiles/ayse`)));
  });

  it('üyeler okuyabilir ama üye listesini değiştiremez', async () => {
    await assertSucceeds(getDoc(doc(db('resul'), `couples/${C}`)));
    await assertFails(updateDoc(doc(db('resul'), `couples/${C}`), { members: ['resul', 'mallory'] }));
    await assertSucceeds(updateDoc(doc(db('resul'), `couples/${C}`), { relationshipStartDate: Timestamp.now() }));
  });

  it('arşivlenen çift alanına erişim kapanır', async () => {
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), `couples/${C}`), { status: 'archived' }));
    await assertFails(getDoc(doc(db('ayse'), `couples/${C}`)));
    await assertFails(getDocs(collection(db('ayse'), `couples/${C}/messages`)));
  });
});

describe('messages', () => {
  const base = (sender) => ({
    senderId: sender, type: 'text', text: 'Seni seviyorum', createdAt: serverTimestamp(), clientTime: Timestamp.now(),
    seenBy: [sender], deletedFor: [], reactions: {}, pinned: false,
  });

  it('üye mesaj gönderir; göndereni taklit edemez', async () => {
    await assertSucceeds(setDoc(doc(db('resul'), `couples/${C}/messages/new1`), base('resul')));
    await assertFails(setDoc(doc(db('resul'), `couples/${C}/messages/new2`), base('ayse')));
    await assertFails(setDoc(doc(db('mallory'), `couples/${C}/messages/new3`), base('mallory')));
  });

  it('partnerin mesajını düzenleyemez, yalnızca kendi tepkisini ekler', async () => {
    const m = doc(db('resul'), `couples/${C}/messages/m1`);
    await assertFails(updateDoc(m, { text: 'hack', editedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(m, { 'reactions.resul': '❤️' }));
    await assertFails(updateDoc(m, { 'reactions.ayse': '😡' }));
    await assertSucceeds(updateDoc(m, { seenBy: arrayUnion('resul') }));
  });
});

describe('questions & answers', () => {
  it('partnerin cevabı, kendi cevabını yazmadan okunamaz', async () => {
    const r = db('resul');
    await assertFails(getDoc(doc(r, `couples/${C}/answers/b_1_ayse`)));
    const batch = writeBatch(r);
    batch.set(doc(r, `couples/${C}/answers/b_1_resul`), {
      uid: 'resul', questionId: 'b_1', text: 'Benim cevabım', createdAt: serverTimestamp(),
    });
    batch.update(doc(r, `couples/${C}/questions/b_1`), { answeredBy: arrayUnion('resul') });
    await assertSucceeds(batch.commit());
    await assertSucceeds(getDoc(doc(r, `couples/${C}/answers/b_1_ayse`)));
  });

  it('başkası adına cevap yazılamaz', async () => {
    await assertFails(setDoc(doc(db('resul'), `couples/${C}/answers/b_1_ayse`), {
      uid: 'ayse', questionId: 'b_1', text: 'x', createdAt: serverTimestamp(),
    }));
  });
});

describe('moods', () => {
  it('gizlenen ruh hali partnere kapalıdır', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `couples/${C}/moods/2026-09-28_ayse`), { uid: 'ayse', day: '2026-09-28', emoji: '😊' });
      await setDoc(doc(ctx.firestore(), `couples/${C}/moods/2026-09-28_resul`), { uid: 'resul', day: '2026-09-28', emoji: '😍' });
    });
    await assertFails(getDoc(doc(db('resul'), `couples/${C}/moods/2026-09-28_ayse`)));
    await assertSucceeds(getDoc(doc(db('ayse'), `couples/${C}/moods/2026-09-28_resul`)));
  });
});

describe('capsules', () => {
  it('açılma tarihinden önce alıcı içeriği okuyamaz, oluşturan okur', async () => {
    await assertSucceeds(getDoc(doc(db('resul'), `couples/${C}/capsules/cap1`)));
    await assertFails(getDoc(doc(db('resul'), `couples/${C}/capsules/cap1/content/main`)));
    await assertSucceeds(getDoc(doc(db('ayse'), `couples/${C}/capsules/cap1/content/main`)));
  });

  it('açılma zamanı gelince alıcı okuyabilir; kilitli kapsül değiştirilemez', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), `couples/${C}/capsules/cap1`), { openAt: Timestamp.fromMillis(Date.now() - 1000) }));
    await assertSucceeds(getDoc(doc(db('resul'), `couples/${C}/capsules/cap1/content/main`)));
    await assertFails(updateDoc(doc(db('ayse'), `couples/${C}/capsules/cap1`), { openAt: Timestamp.now() }));
  });
});

describe('storage', () => {
  it('çift dosyalarını yalnızca üyeler okur/yükler', async () => {
    const file = new Uint8Array([1, 2, 3]);
    const path = `couples/${C}/chat/m1/a.jpg`;
    await assertSucceeds(uploadBytes(ref(env.authenticatedContext('ayse').storage(), path), file, { contentType: 'image/jpeg' }));
    await assertSucceeds(getBytes(ref(env.authenticatedContext('resul').storage(), path)));
    await assertFails(getBytes(ref(env.authenticatedContext('mallory').storage(), path)));
    await assertFails(uploadBytes(ref(env.authenticatedContext('mallory').storage(), `couples/${C}/chat/x/b.jpg`), file, { contentType: 'image/jpeg' }));
  });

  it('kapsül dosyası açılmadan alıcıya kapalı', async () => {
    const path = `couples/${C}/capsules/cap1/p.jpg`;
    await env.withSecurityRulesDisabled((ctx) => uploadBytes(ref(ctx.storage(), path), new Uint8Array([1]), { contentType: 'image/jpeg' }));
    await assertFails(getBytes(ref(env.authenticatedContext('resul').storage(), path)));
    await assertSucceeds(getBytes(ref(env.authenticatedContext('ayse').storage(), path)));
  });
});
