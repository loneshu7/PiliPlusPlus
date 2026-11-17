import 'package:PiliPlus/plugin/pl_player/exo_player/exo_player_controller.dart';
import 'package:PiliPlus/plugin/pl_player/exo_player/exo_subtitle_view.dart';
import 'package:PiliPlus/plugin/pl_player/models/subtitle_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('com.example.piliplus/exo_player');
  const events = MethodChannel('com.example.piliplus/exo_player_events');

  setUp(() {
    binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(methods, (call) async {
        return call.method == 'create' ? 1 : null;
      })
      ..setMockMethodCallHandler(events, (_) async => null);
  });
  tearDown(() {
    binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(methods, null)
      ..setMockMethodCallHandler(events, null);
  });

  for (final enableDrag in [true, false]) {
    testWidgets(
      'subtitle overlay preserves video gestures (drag=$enableDrag)',
      (
        tester,
      ) async {
        final player = await ExoPlayerController.create();
        addTearDown(player.dispose);
        player.state = ExoPlayerEvent.fromMap({
          'subtitleCues': [
            {'text': 'Test subtitle'},
          ],
        });
        var taps = 0;
        var videoDrags = 0;
        final paddingUpdates = <EdgeInsets>[];
        const videoKey = ValueKey('video');
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                key: videoKey,
                width: 400,
                height: 300,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      onVerticalDragUpdate: (_) => videoDrags++,
                      child: const ColoredBox(color: Colors.black),
                    ),
                    ExoSubtitleView(
                      controller: player,
                      configuration: const PlayerSubtitleStyle(),
                      enableDragSubtitle: enableDrag,
                      onUpdatePadding: paddingUpdates.add,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final video = tester.getRect(find.byKey(videoKey));
        final pointAboveSubtitle = video.topLeft + const Offset(50, 50);
        await tester.tapAt(pointAboveSubtitle);
        expect(
          taps,
          1,
          reason: 'A visible subtitle must not cover the video tap target',
        );
        await tester.dragFrom(pointAboveSubtitle, const Offset(0, 50));
        expect(videoDrags, greaterThan(0));
        expect(paddingUpdates, isEmpty);

        if (enableDrag) {
          final text = find.text('Test subtitle', findRichText: true);
          final oldTop = tester.getTopLeft(text).dy;
          await tester.drag(text, const Offset(0, -40));
          await tester.pumpAndSettle();
          expect(paddingUpdates, hasLength(1));
          expect(paddingUpdates.single.bottom, greaterThan(24));
          expect(tester.getTopLeft(text).dy, lessThan(oldTop));
        } else {
          await tester.tapAt(
            tester.getCenter(find.text('Test subtitle', findRichText: true)),
          );
          expect(
            taps,
            2,
            reason: 'Non-draggable subtitles should pass taps through',
          );
        }
      },
    );
  }
}
