import 'package:PiliPlus/plugin/pl_player/exo_player/exo_player_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('com.example.piliplus/exo_player');
  const events = MethodChannel('com.example.piliplus/exo_player_events');
  const codec = StandardMethodCodec();

  setUp(() {
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methods, (call) async {
      return call.method == 'create' ? 1 : null;
    });
    messenger.setMockMethodCallHandler(events, (_) async => null);
  });

  tearDown(() {
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
  });

  Future<void> emit(
    ExoPlayerController player,
    Map<String, Object?> state, {
    bool accepted = true,
  }) async {
    final nextEvent = accepted ? player.events.first : null;
    binding.channelBuffers.push(
      events.name,
      codec.encodeSuccessEnvelope({'id': player.id, ...state}),
      (_) {},
    );
    if (nextEvent != null) {
      await nextEvent;
    } else {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'a new source needs its own ready state before automatic skips',
    () async {
      final player = await ExoPlayerController.create();
      addTearDown(player.dispose);
      await emit(player, {'generation': 0, 'ready': true, 'positionMs': 30000});
      expect(player.isCurrentMediaReady, isTrue);

      await player.open(videoUrl: 'https://example.com/new.mp4', headers: {});
      expect(player.isCurrentMediaReady, isFalse);
      await emit(player, {
        'generation': 0,
        'ready': true,
        'positionMs': 31000,
      }, accepted: false);
      expect(player.isCurrentMediaReady, isFalse);

      // Native open may clear subtitles before prepare emits the new state.
      await emit(player, {'generation': 1, 'type': 'subtitle', 'subtitle': ''});
      expect(player.isCurrentMediaReady, isFalse);
      await emit(player, {'generation': 1, 'ready': false, 'positionMs': 0});
      expect(player.isCurrentMediaReady, isFalse);
      await emit(player, {'generation': 1, 'ready': true, 'positionMs': 0});
      expect(player.isCurrentMediaReady, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test('buffering suspends readiness until a ready state resumes', () async {
    final player = await ExoPlayerController.create();
    addTearDown(player.dispose);
    await emit(player, {'generation': 0, 'ready': true});
    expect(player.isCurrentMediaReady, isTrue);
    await emit(player, {'generation': 0, 'ready': false, 'buffering': true});
    expect(player.isCurrentMediaReady, isFalse);
    await emit(player, {
      'generation': 0,
      'type': 'subtitle',
      'subtitle': 'pending',
    });
    expect(player.isCurrentMediaReady, isFalse);
    await emit(player, {'generation': 0, 'ready': true, 'buffering': false});
    expect(player.isCurrentMediaReady, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
