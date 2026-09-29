import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../features/questions/domain/question_bank.dart';
import '../../features/settings/domain/user_settings.dart';
import '../../firebase_options.dart';
import '../services/firebase_providers.dart';
import '../services/presence_service.dart';
import '../utils/date_x.dart';

/// Demo modu: Firebase projesi bağlanmadan uygulamanın tamamını denemek için
/// cihaz içinde çalışan sahte Firestore/Auth/Storage ve örnek veriler.
///
/// `--dart-define=DEMO_MODE=true` ile ya da `firebase_options.dart` henüz
/// `flutterfire configure` ile üretilmemişse otomatik açılır.
final bool kDemoMode = const bool.fromEnvironment('DEMO_MODE') ||
    DefaultFirebaseOptions.android.apiKey.startsWith('REPLACE');

const kDemoEmail = 'demo@visal.app';
const kDemoPassword = 'visal2026';
const _me = 'demo_me';
const _partner = 'demo_partner';
const _couple = 'demo_couple';

Future<List<Override>> demoOverrides() async {
  final db = FakeFirebaseFirestore();
  await _seed(db);
  final auth = MockFirebaseAuth(
    mockUser: MockUser(uid: _me, email: kDemoEmail, displayName: 'Deniz'),
  );
  _DemoPartner(db).start();
  return [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(db),
    storageProvider.overrideWithValue(MockFirebaseStorage()),
    presenceServiceProvider.overrideWith((ref) => _DemoPresence(ref.watch(realtimeDbProvider))),
    partnerPresenceProvider.overrideWith((ref) => _partnerPresence()),
  ];
}

// ---------------------------------------------------------------------------
// Presence: partner "yazıyor…" ve çevrimiçi durumunu taklit eder.
// ---------------------------------------------------------------------------

final _typingController = StreamController<bool>.broadcast();

Stream<PresenceState> _partnerPresence() async* {
  yield const PresenceState(online: true);
  await for (final typing in _typingController.stream) {
    yield PresenceState(online: true, typing: typing);
  }
}

class _DemoPresence extends PresenceService {
  _DemoPresence(super.db);

  @override
  void goOnline(String uid, PrivacySettings privacy) {}

  @override
  Future<void> goOffline() async {}

  @override
  void setTyping(bool typing) {}

  @override
  Future<void> signOut() async {}
}

// ---------------------------------------------------------------------------
// Demo partner: mesajlara cevap verir, okundu işaretler.
// ---------------------------------------------------------------------------

class _DemoPartner {
  _DemoPartner(this.db);

  final FakeFirebaseFirestore db;
  final _rand = Random();
  final _seen = <String>{};
  bool _initial = true;

  static const _replies = [
    'Ben de seni çok seviyorum ❤️',
    'Az önce seni düşünüyordum 🥰',
    'Akşam ne yapıyoruz?',
    'Bunu duyduğuma çok sevindim ✨',
    'Hahaha 😂 çok tatlısın',
    'Eve gelirken bir şey alayım mı?',
    'Hafta sonu kısa bir kaçamak yapalım mı? 🏖️',
    'Özledim seni 🥺',
  ];

  static const _loveReplies = {
    'love': '❤️ Seni seviyorum',
    'miss': '🥺 Özledim',
    'home': '🏠 Eve geliyorum',
    'coffee': '☕ Kahve?',
    'call': '📞 Müsait misin?',
    'kiss': '😘 Öpücük',
  };

  CollectionReference<Map<String, dynamic>> get _messages =>
      db.collection('couples/$_couple/messages');

  void start() {
    _messages
        .where('senderId', isEqualTo: _me)
        .snapshots()
        .listen((snap) {
      for (final d in snap.docs) {
        if (_seen.add(d.id) && !_initial) _respond(d);
      }
      _initial = false;
    });
    // Birkaç saniye sonra partnerden "seni düşünüyor" animasyonu.
    Timer(const Duration(seconds: 25), () => _send({
          'type': 'love',
          'text': '❤️ Seni seviyorum',
          'loveKind': 'love',
        }));
  }

  Future<void> _respond(DocumentSnapshot<Map<String, dynamic>> mine) async {
    final data = mine.data() ?? const {};
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await mine.reference.update({
      'seenBy': FieldValue.arrayUnion([_partner]),
    });
    _typingController.add(true);
    await Future<void>.delayed(Duration(milliseconds: 1400 + _rand.nextInt(1400)));
    _typingController.add(false);
    if (data['type'] == 'love') {
      final kind = data['loveKind'] as String? ?? 'love';
      await _send({
        'type': 'love',
        'text': _loveReplies[kind == 'love' ? 'kiss' : 'love'],
        'loveKind': kind == 'love' ? 'kiss' : 'love',
      });
      return;
    }
    if (_rand.nextBool()) {
      await mine.reference.update({'reactions.$_partner': '❤️'});
    }
    await _send({'type': 'text', 'text': _replies[_rand.nextInt(_replies.length)]});
  }

  Future<void> _send(Map<String, dynamic> m) => _messages.add({
        'senderId': _partner,
        'createdAt': Timestamp.now(),
        'clientTime': Timestamp.now(),
        'seenBy': [_partner],
        'deletedFor': <String>[],
        'reactions': <String, String>{},
        'pinned': false,
        ...m,
      });
}

// ---------------------------------------------------------------------------
// Örnek veriler
// ---------------------------------------------------------------------------

String _img(String seed, [int w = 1200, int h = 900]) => 'https://picsum.photos/seed/$seed/$w/$h';

Map<String, dynamic> _photo(String seed) => {
      'url': _img(seed),
      'thumbUrl': _img(seed, 480, 360),
      'path': '',
      'type': 'image',
      'width': 1200,
      'height': 900,
    };

Future<void> _seed(FakeFirebaseFirestore db) async {
  final now = DateTime.now();
  final today = dateOnly(now);
  Timestamp ts(DateTime d) => Timestamp.fromDate(d);
  final start = today.subtract(const Duration(days: 1325));
  final settings = const UserSettings().toMap();

  await db.doc('users/$_me').set({
    'uid': _me,
    'name': 'Deniz',
    'email': kDemoEmail,
    'photoUrl': _img('visal-me', 400, 400),
    'coupleId': _couple,
    'birthday': ts(DateTime(1996, today.month, today.day).add(const Duration(days: 59))),
    'createdAt': ts(start),
    'lastSeen': ts(now),
    'settings': settings,
  });
  await db.doc('users/$_partner').set({
    'uid': _partner,
    'name': 'Ayşe',
    'email': 'ayse@visal.app',
    'coupleId': _couple,
    'settings': settings,
  });

  final c = 'couples/$_couple';
  await db.doc(c).set({
    'members': [_me, _partner],
    'status': 'active',
    'relationshipStartDate': ts(start),
    'anniversaryDate': ts(DateTime(start.year, today.month, today.day).add(const Duration(days: 23))),
    'theme': 'default',
    'coverPhoto': null,
    'createdAt': ts(start),
  });
  await db.doc('$c/profiles/$_me').set({
    'name': 'Deniz',
    'photoUrl': _img('visal-me', 400, 400),
    'birthday': ts(DateTime(1996, today.month, today.day).add(const Duration(days: 59))),
    'moodVisible': true,
  });
  await db.doc('$c/profiles/$_partner').set({
    'name': 'Ayşe',
    'photoUrl': _img('visal-ayse', 400, 400),
    'birthday': ts(DateTime(1997, 3, 12)),
    'moodVisible': true,
  });

  // Mesajlar: sayfalamayı göstermek için 3 güne yayılmış 60 mesaj.
  const lines = [
    ('p', 'Günaydın güzelim ☀️'),
    ('m', 'Günaydın 🥰 uyandın mı?'),
    ('p', 'Kahve yaptım, keşke burada olsan'),
    ('m', 'Akşam erken gelirim, film izleriz'),
    ('p', 'Anlaştık! Patlamış mısır bende 🍿'),
    ('m', 'Bugün toplantılar çok uzun sürdü'),
    ('p', 'Yorulmuşsundur, akşam sana masaj 😌'),
    ('m', 'En iyisisin ❤️'),
    ('p', 'Hafta sonu için bir fikrim var'),
    ('m', 'Söyle bakalım 👀'),
    ('p', 'Kapadokya? Balon turu?'),
    ('m', 'Harika olur! Hemen plan yapalım'),
  ];
  final rand = Random(7);
  for (var i = 0; i < 60; i++) {
    final line = lines[i % lines.length];
    final at = now.subtract(Duration(minutes: (60 - i) * 70 + rand.nextInt(20)));
    final sender = line.$1 == 'm' ? _me : _partner;
    await db.collection('$c/messages').add({
      'senderId': sender,
      'type': 'text',
      'text': line.$2,
      'createdAt': ts(at),
      'clientTime': ts(at),
      'seenBy': [_me, _partner],
      'deletedFor': <String>[],
      'reactions': i % 7 == 0 ? {_me: '❤️'} : <String, String>{},
      'pinned': i == 40,
      if (i == 40) 'pinnedAt': ts(at),
    });
  }
  final photoAt = now.subtract(const Duration(minutes: 30));
  await db.collection('$c/messages').add({
    'senderId': _partner,
    'type': 'image',
    'mediaUrl': _img('visal-chat'),
    'media': _photo('visal-chat'),
    'text': 'Bugünkü manzara 🌅',
    'createdAt': ts(photoAt),
    'clientTime': ts(photoAt),
    'seenBy': [_me, _partner],
    'deletedFor': <String>[],
    'reactions': <String, String>{},
    'pinned': false,
  });

  // Anılar
  final memories = [
    ('İlk buluşmamız', 'Moda sahilinde saatlerce yürüdük, simit ve çay…', 1300, '🌹', true, false, 'Moda, İstanbul'),
    ('Kapadokya', 'Gün doğumunda balonlar. Hayatımın en güzel sabahı.', 365 * 2, '🎈', true, true, 'Göreme'),
    ('Yılbaşı', 'Evde, battaniye altında, sadece ikimiz.', 270, '✨', true, false, null),
    ('Kaş tatili', 'Turkuaz deniz, akşam yemekleri ve yıldızlar.', 90, '🏖️', false, true, 'Kaş, Antalya'),
    ('Konser gecesi', 'En sevdiğimiz şarkıda birlikte bağırdık 🎶', 40, '🎶', false, false, 'Harbiye'),
    ('Pazar kahvaltısı', 'Tembel, uzun ve çok güzel bir sabah.', 6, '☕', false, false, null),
  ];
  for (var i = 0; i < memories.length; i++) {
    final m = memories[i];
    final date = m.$3 == 365 * 2
        ? DateTime(today.year - 2, today.month, today.day)
        : today.subtract(Duration(days: m.$3));
    await db.collection('$c/memories').add({
      'createdBy': i.isEven ? _me : _partner,
      'title': m.$1,
      'description': m.$2,
      'date': ts(date),
      'monthDay': monthDayKey(date),
      'year': date.year,
      'media': [_photo('visal-mem-$i'), if (i == 1) _photo('visal-mem-b')],
      'location': m.$7,
      'emoji': m.$4,
      'musicUrl': i == 4 ? 'https://open.spotify.com' : null,
      'isSpecial': m.$5,
      'isTravel': m.$6,
      'hasPhoto': true,
      'hasVideo': false,
      'createdAt': ts(date),
    });
  }

  // Bizim Hikâyemiz
  final story = [
    ('firstMessage', 'İlk mesaj', 1330),
    ('firstDate', 'İlk buluşma', 1325),
    ('firstTrip', 'İlk tatil', 1000),
    ('engagement', 'Nişan', 300),
  ];
  for (final s in story) {
    await db.collection('$c/timeline').add({
      'type': s.$1,
      'title': s.$2,
      'date': ts(today.subtract(Duration(days: s.$3))),
      'createdBy': _me,
      'description': '',
      'photoUrl': s.$1 == 'firstDate' ? _img('visal-story') : null,
    });
  }

  // Planlar
  Future<void> event(String title, String cat, int inDays, {String? time, String repeat = 'none', String? loc}) {
    final d = today.add(Duration(days: inDays));
    return db.collection('$c/events').add({
      'title': title,
      'category': cat,
      'date': ts(d),
      'startsAt': ts(d),
      'time': time,
      'location': loc,
      'note': null,
      'reminder': 60,
      'repeat': repeat,
      'color': null,
      'createdBy': _me,
      'createdAt': ts(now),
    });
  }

  await event('Akşam yemeği', 'date', 0, time: '20:00', loc: 'Karaköy');
  await event('Sinema', 'activity', 3, time: '21:15');
  await event('Kapadokya', 'travel', 12, loc: 'Göreme');
  await event('Ev temizliği', 'home', 5, repeat: 'weekly');
  for (var i = 0; i < 48; i++) {
    // Plan sayacı için geçmiş etkinlikler
    await db.collection('$c/events').add({
      'title': 'Randevu #$i',
      'category': 'date',
      'date': ts(today.subtract(Duration(days: 20 + i * 18))),
      'startsAt': ts(today.subtract(Duration(days: 20 + i * 18))),
      'time': null,
      'reminder': null,
      'repeat': 'none',
      'createdBy': _partner,
    });
  }

  final tasks = [
    ('Uçak biletlerini al', _me, false, 2),
    ('Anneme çiçek gönder', _partner, false, 1),
    ('Balkon bitkilerini sula', 'both', false, 0),
    ('Otel rezervasyonu', _partner, true, -3),
  ];
  for (final t in tasks) {
    await db.collection('$c/tasks').add({
      'title': t.$1,
      'description': '',
      'dueDate': ts(today.add(Duration(days: t.$4))),
      'assignee': t.$2,
      'done': t.$3,
      'doneBy': t.$3 ? _partner : null,
      'createdBy': _me,
      'createdAt': ts(now.subtract(Duration(minutes: tasks.indexOf(t)))),
    });
  }

  final goals = [
    ('Birlikte 100 film', 43, 100, 'film', '🎬', 1),
    ('Tatil', 32000, 100000, 'TL', '💰', 1000),
    ('10 şehir', 4, 10, 'şehir', '🏙️', 1),
  ];
  for (final g in goals) {
    await db.collection('$c/goals').add({
      'title': g.$1,
      'current': g.$2,
      'target': g.$3,
      'unit': g.$4,
      'emoji': g.$5,
      'step': g.$6,
      'createdBy': _me,
      'createdAt': ts(now.subtract(Duration(days: goals.indexOf(g)))),
    });
  }

  // Günün sorusu: partner cevapladı, cevabın bekleniyor.
  final daily = QuestionBank.forDay(now, _couple);
  final qid = 'd_${dayKey(now)}';
  await db.doc('$c/questions/$qid').set({
    'text': daily.text,
    'category': daily.category.name,
    'bankId': daily.id,
    'day': dayKey(now),
    'answeredBy': [_partner],
    'createdAt': ts(now),
  });
  await db.doc('$c/answers/${qid}_$_partner').set({
    'uid': _partner,
    'questionId': qid,
    'text': 'Seninle ilk kez gün doğumunu izlediğimiz o sabah. Hiç bitmesin istemiştim.',
    'createdAt': ts(now),
  });
  final past = QuestionBank.all[3];
  await db.doc('$c/questions/${past.id}').set({
    'text': past.text,
    'category': past.category.name,
    'bankId': past.id,
    'day': null,
    'answeredBy': [_me, _partner],
    'createdAt': ts(now.subtract(const Duration(days: 2))),
  });
  await db.doc('$c/answers/${past.id}_$_me').set({
    'uid': _me,
    'questionId': past.id,
    'text': 'Bir yağmurlu akşam, aynı şemsiyenin altında.',
    'createdAt': ts(now.subtract(const Duration(days: 2))),
  });
  await db.doc('$c/answers/${past.id}_$_partner').set({
    'uid': _partner,
    'questionId': past.id,
    'text': 'Beni ilk güldürdüğün an 😊',
    'createdAt': ts(now.subtract(const Duration(days: 2))),
  });

  // Ruh hali
  await db.doc('$c/moods/${dayKey(now)}_$_partner').set({
    'uid': _partner,
    'day': dayKey(now),
    'emoji': '😊',
    'createdAt': ts(now),
  });

  // Kapsüller: biri kilitli (partnerden), biri açılmış.
  final locked = db.collection('$c/capsules').doc();
  await locked.set({
    'createdBy': _partner,
    'recipientId': _me,
    'openAt': ts(today.add(const Duration(days: 23, hours: 9))),
    'title': 'Yıldönümümüz için',
    'hasPhoto': true,
    'hasVideo': false,
    'hasAudio': false,
    'notified': false,
    'createdAt': ts(now.subtract(const Duration(days: 10))),
  });
  await locked.collection('content').doc('main').set({'message': 'Sürpriz! 💝', 'media': <dynamic>[]});
  final opened = db.collection('$c/capsules').doc();
  await opened.set({
    'createdBy': _partner,
    'recipientId': _me,
    'openAt': ts(now.subtract(const Duration(days: 1))),
    'title': 'Bir yıl önceki benden',
    'hasPhoto': false,
    'hasVideo': false,
    'hasAudio': false,
    'notified': true,
    'createdAt': ts(now.subtract(const Duration(days: 366))),
  });
  await opened.collection('content').doc('main').set({
    'message': 'Bunu okuduğunda bir yıl geçmiş olacak. Umarım hâlâ her sabah ilk mesajı sen atıyorsundur. '
        'Seninle geçen her gün için teşekkür ederim. ❤️',
    'media': <dynamic>[],
  });

  // Bildirim kutusu
  await db.collection('users/$_me/inbox').add({
    'type': 'memory',
    'title': 'Yeni anı ✨',
    'body': 'Ayşe bir anı ekledi: Kaş tatili',
    'route': '/memories',
    'read': false,
    'createdAt': ts(now.subtract(const Duration(hours: 3))),
  });
  await db.collection('users/$_me/inbox').add({
    'type': 'capsule',
    'title': 'Sana bir kapsül bırakıldı ⏳',
    'body': 'Ayşe sana bir anı kapsülü bıraktı.',
    'route': '/capsules',
    'read': false,
    'createdAt': ts(now.subtract(const Duration(days: 10))),
  });
}
