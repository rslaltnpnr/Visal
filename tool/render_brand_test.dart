// Marka varlıklarını PNG olarak üretir:
//   flutter test tool/render_brand_test.dart --update-goldens
// Çıktılar: tool/goldens/*.png (splash_mark.png -> assets/icon/ altına kopyalanır)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visal/core/widgets/visal_logo.dart';

Future<void> loadAppFonts() async {
  final loader = FontLoader('PlusJakartaSans');
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await loader.load();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('splash mark', (tester) async {
    tester.view.physicalSize = const Size(576, 576);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const RepaintBoundary(
      child: Center(child: VisalMark(size: 380)),
    ));
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/splash_mark.png'),
    );
  });

  testWidgets('brand preview', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        child: Container(
          color: const Color(0xFFF8F4EF),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  VisalAppIcon(size: 220),
                  VisalMark(size: 220, tone: MarkTone.onLight),
                ],
              ),
              VisalHorizontalLogo(height: 70, onDark: false),
            ],
          ),
        ),
      ),
    ));
    await expectLater(
      find.byType(RepaintBoundary).first,
      matchesGoldenFile('goldens/brand_preview.png'),
    );
  });
}
