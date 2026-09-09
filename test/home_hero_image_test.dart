import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quest_up/features/quests/presentation/screens/home_radar_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomeRadarScreen renders hero gamer card with assets/images/hero_card.png',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: HomeRadarScreen(),
        ),
      ),
    );

    // Pump frames
    await tester.pumpAndSettle();

    // Verify Image.asset with assets/images/hero_card.png exists (handles direct AssetImage or optimized ResizeImage)
    final imageFinder = find.byWidgetPredicate(
      (widget) {
        if (widget is! Image) return false;
        final img = widget.image;
        if (img is AssetImage) return img.assetName == 'assets/images/hero_card.png';
        if (img is ResizeImage && img.imageProvider is AssetImage) {
          return (img.imageProvider as AssetImage).assetName == 'assets/images/hero_card.png';
        }
        return false;
      },
    );

    expect(imageFinder, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
