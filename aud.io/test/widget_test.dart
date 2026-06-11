import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aud_io/main.dart';
import 'package:aud_io/services/audio_handler.dart';
import 'package:aud_io/widgets/golden_spiral_nav.dart';

void main() {
  testWidgets('app loads and shows golden spiral navigation', (WidgetTester tester) async {
    await tester.pumpWidget(AudIoApp(audioHandler: AppAudioHandler(), enableSupabase: false));
    await tester.pump();

    expect(find.byType(GoldenSpiralNav), findsOneWidget);
    // Section 0 (Discover) is active, so the other sections render as
    // spiral preview panels with their labels.
    expect(find.text('PODCASTS'), findsWidgets);
    expect(find.text('SETTINGS'), findsWidgets);
  });

  testWidgets('spiral panels fit a phone-sized screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AudIoApp(audioHandler: AppAudioHandler(), enableSupabase: false));
    await tester.pump();

    expect(find.byType(GoldenSpiralNav), findsOneWidget);

    // Navigate to another section and let the spiral animation settle.
    await tester.tap(find.text('SETTINGS'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('DISCOVER'), findsWidgets);
  });
}
