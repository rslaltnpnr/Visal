enum QuestionCategory {
  romantic('Romantik', '🌹'),
  fun('Eğlenceli', '😄'),
  past('Geçmiş', '📜'),
  future('Gelecek', '🔭'),
  dreams('Hayaller', '✨'),
  relationship('İlişki', '🤍'),
  travel('Seyahat', '✈️'),
  film('Film', '🎬'),
  music('Müzik', '🎵'),
  knowEachOther('Birbirimizi ne kadar tanıyoruz?', '🧩');

  const QuestionCategory(this.label, this.emoji);

  final String label;
  final String emoji;
}

class BankQuestion {
  const BankQuestion(this.index, this.category, this.text);

  final int index;
  final QuestionCategory category;
  final String text;

  String get id => 'b_$index';
}

/// Uygulama içi soru bankası. Günün sorusu, tarih ve çift kimliğinden
/// deterministik seçilir; iki partner de aynı soruyu görür.
abstract final class QuestionBank {
  static const _raw = <QuestionCategory, List<String>>{
    QuestionCategory.romantic: [
      'Birlikte tekrar yaşamak istediğin gün hangisi?',
      'Bana âşık olduğunu ilk ne zaman fark ettin?',
      'Seni en çok neyle şımartmamı istersin?',
      'Bizim için en romantik akşam nasıl olurdu?',
      'Bana hiç söylemediğin ama hep düşündüğün bir iltifat ne?',
      'Hangi şarkı sana beni hatırlatıyor?',
      'Seni en çok hangi küçük jestim mutlu ediyor?',
      'İlk öpücüğümüzü nasıl hatırlıyorsun?',
      'Bana yazmak istediğin bir mektubun ilk cümlesi ne olurdu?',
      'Birlikteyken zamanın durmasını istediğin an hangisiydi?',
      'Sence en güzel sarılmamız hangisiydi?',
      'Beni tek kelimeyle anlatsan ne derdin?',
    ],
    QuestionCategory.fun: [
      'Bir gün boyunca yer değiştirsek ilk ne yapardın?',
      'Birlikte bir yarışma programına katılsak hangisini kazanırdık?',
      'Ortak bir süper gücümüz olsa ne olurdu?',
      'Bir hayvan olsaydım hangisi olurdum sence?',
      'Birlikte açacağımız dükkânın adı ne olurdu?',
      'En komik anımız hangisi?',
      'Benim en tuhaf alışkanlığım ne?',
      'Hayatımız bir dizi olsa adı ne olurdu?',
      'Birlikte bir dans şovu yapsak hangi şarkıyı seçerdin?',
      'Bir gün boyunca sadece tek bir yemek yiyebilsek ne olurdu?',
      'Beni en çok ne güldürüyor?',
      'Bir filmde oynasak hangi türde olurdu?',
    ],
    QuestionCategory.past: [
      'Çocukken en sevdiğin oyun neydi?',
      'Tanışmadan önceki hayatından en çok neyi özlüyorsun?',
      'İlk buluşmamızda aklından neler geçiyordu?',
      'Hayatındaki en cesur karar hangisiydi?',
      'Bana ilk mesajını yazarken ne hissettin?',
      'Seni sen yapan bir anı paylaşır mısın?',
      'Okul yıllarından unutamadığın bir an?',
      'Birlikte geçirdiğimiz en zor gün hangisiydi ve bize ne kattı?',
      'Ailenden öğrendiğin en değerli şey ne?',
      'İlişkimizin ilk ayından aklında kalan tek sahne?',
      'Hiç kimseye anlatmadığın komik bir anın var mı?',
      'Geçmişteki kendine bir şey söyleyebilsen ne derdin?',
    ],
    QuestionCategory.future: [
      '5 yıl sonra bir pazar sabahımız nasıl olsun?',
      'Birlikte öğrenmek istediğin bir şey ne?',
      'Hayalindeki evin en sevdiğin köşesi neresi?',
      'Yaşlandığımızda birlikte ne yapıyor olmak istersin?',
      'Bu yıl birlikte başarmak istediğimiz tek şey ne?',
      'Gelecekte kutlamak istediğin bir yıldönümü planı var mı?',
      'Birlikte bir gelenek başlatsak ne olurdu?',
      'Önümüzdeki ay için küçük bir hedefimiz ne olsun?',
      'Emekli olduğumuzda nerede yaşamak istersin?',
      'Gelecekteki bize bir not bıraksan ne yazardın?',
      'Birlikte kurmak istediğin bir rutin var mı?',
      '10 yıl sonra bu soruyu okuyunca ne hissetmek istersin?',
    ],
    QuestionCategory.dreams: [
      'Hiçbir engel olmasaydı hangi mesleği seçerdin?',
      'Gerçekleşmesini en çok istediğin hayalin ne?',
      'Bir yıl boyunca istediğin yerde yaşayabilsen neresi olurdu?',
      'Kendi kitabını yazsan konusu ne olurdu?',
      'Hayalindeki bir günü baştan sona anlatır mısın?',
      'Birlikte yapmak istediğin çılgın bir şey?',
      'Hangi yeteneğe sahip olmak isterdin?',
      'Dünyada bir şeyi değiştirebilsen ne olurdu?',
      'Çocukken büyüyünce ne olmak isterdin?',
      'Hayallerinden hangisini benimle paylaşmak istersin?',
      'Bir gün kurmak istediğin iş ne?',
      'Hayalindeki tatil nasıl bir şey?',
    ],
    QuestionCategory.relationship: [
      'Kendini en çok ne zaman sevilmiş hissediyorsun?',
      'İlişkimizde en çok gurur duyduğun şey ne?',
      'Tartıştığımızda senin için en iyi barışma yolu ne?',
      'Sence birbirimizi en iyi tamamladığımız yön hangisi?',
      'Benden daha sık duymak istediğin bir cümle var mı?',
      'İlişkimizde korumak istediğin bir alışkanlık?',
      'Sana en iyi nasıl destek olabilirim?',
      'Bizi diğer çiftlerden farklı kılan ne?',
      'Son zamanlarda sana iyi gelen bir davranışım oldu mu?',
      'Birlikte daha fazla yapmak istediğin şey ne?',
      'Sevgi dilin hangisi sence?',
      'İlişkimizi bir renkle anlatsan hangisi olurdu?',
    ],
    QuestionCategory.travel: [
      'Birlikte gitmek istediğin ilk ülke neresi?',
      'Deniz mi dağ mı, neden?',
      'Unutulmaz bir yolculuk anını anlat.',
      'Bir hafta sonu kaçamağı için en ideal yer neresi?',
      'Seyahatte vazgeçemediğin bir şey ne?',
      'Karavanla yola çıksak ilk durağımız neresi olurdu?',
      'Hangi şehirde bir gün sokak sokak kaybolmak isterdin?',
      'En sevdiğin tatil anımız hangisi?',
      'Balon turu mu, dalış mı?',
      'Birlikte görmek istediğin doğa harikası?',
      'Seyahatte planlı mı olmayı seversin, plansız mı?',
      'Bir ülkenin mutfağını keşfetmek için nereye giderdin?',
    ],
    QuestionCategory.film: [
      'Birlikte izlediğimiz en iyi film hangisiydi?',
      'Hayatımızın filmini hangi yönetmen çekmeli?',
      'Tekrar tekrar izleyebileceğin film?',
      'Hangi film karakterine benziyorum?',
      'Bir film gecesi için atıştırmalık seçimin ne?',
      'Seni en çok ağlatan film hangisi?',
      'Birlikte izlememiz gereken bir dizi öner.',
      'En sevdiğin romantik film sahnesi?',
      'Bir filmin içine girebilsen hangisi olurdu?',
      'Korku filmi mi komedi mi?',
      'Çocukluğunun filmi hangisi?',
      'Bizim hikâyemize en çok benzeyen film hangisi?',
    ],
    QuestionCategory.music: [
      'Bizim şarkımız hangisi olmalı?',
      'Şu an en çok dinlediğin şarkı ne?',
      'Birlikte gitmek istediğin konser?',
      'Seni her zaman mutlu eden şarkı hangisi?',
      'Yol şarkısı listemize ilk ne eklenmeli?',
      'Hangi şarkının sözleri seni anlatıyor?',
      'Düğün dansımız hangi şarkıyla olurdu?',
      'Çocukken dinlediğin ve hâlâ sevdiğin bir şarkı?',
      'Bir enstrüman çalabilsen hangisi olurdu?',
      'Yağmurlu bir gün için şarkı önerin?',
      'Beni düşündüren bir şarkı var mı?',
      'Karaokede ikimiz hangi şarkıyı söylemeliyiz?',
    ],
    QuestionCategory.knowEachOther: [
      'En sevdiğim yemek ne?',
      'Kötü bir günümde bana ne iyi gelir?',
      'En büyük korkum ne sence?',
      'Kahvemi nasıl içerim?',
      'Beni en çok ne sinirlendirir?',
      'En sevdiğim renk hangisi?',
      'Çocukluk kahramanım kimdi?',
      'Sabah insanı mıyım, gece insanı mı?',
      'Hayalimdeki meslek neydi?',
      'En sevdiğim mevsim hangisi ve neden?',
      'Hangi konuda saatlerce konuşabilirim?',
      'Beni en iyi anlatan üç kelime ne?',
    ],
  };

  static final List<BankQuestion> all = () {
    final list = <BankQuestion>[];
    var i = 0;
    for (final entry in _raw.entries) {
      for (final text in entry.value) {
        list.add(BankQuestion(i++, entry.key, text));
      }
    }
    return List<BankQuestion>.unmodifiable(list);
  }();

  static List<BankQuestion> byCategory(QuestionCategory c) =>
      all.where((q) => q.category == c).toList();

  static BankQuestion? byId(String id) {
    final idx = int.tryParse(id.replaceFirst('b_', ''));
    if (idx == null || idx < 0 || idx >= all.length) return null;
    return all[idx];
  }

  /// Günün sorusu: çift kimliğine göre karıştırılmış, her gün değişen sıra.
  static BankQuestion forDay(DateTime day, String coupleId) {
    final epochDay = DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 86400000;
    var seed = 0;
    for (final c in coupleId.codeUnits) {
      seed = (seed * 31 + c) & 0x7fffffff;
    }
    // Asal adımla dolaşım: aynı soru uzun süre tekrar etmez.
    const step = 37;
    final index = (seed + epochDay * step) % all.length;
    return all[index];
  }
}
