import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/player_status_builder.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _StatusSource {
  PlayerStatus status = PlayerStatus.paused;
  final listeners = <ValueChanged<PlayerStatus>>{};

  void addListener(ValueChanged<PlayerStatus> listener) =>
      listeners.add(listener);
  void removeListener(ValueChanged<PlayerStatus> listener) =>
      listeners.remove(listener);

  void emit(PlayerStatus value) {
    status = value;
    for (final listener in listeners.toList()) {
      listener(value);
    }
  }
}

Widget _build(_StatusSource source) => Directionality(
  textDirection: TextDirection.ltr,
  child: PlayerStatusBuilder(
    currentStatus: () => source.status,
    addListener: source.addListener,
    removeListener: source.removeListener,
    builder: (_, status) => Text(status.isPlaying ? '暂停' : '播放'),
  ),
);

void main() {
  testWidgets('mini controls rebuild from non-Rx playback status', (
    tester,
  ) async {
    final source = _StatusSource();
    await tester.pumpWidget(_build(source));
    expect(find.text('播放'), findsOneWidget);
    expect(source.listeners, hasLength(1));

    source.emit(PlayerStatus.playing);
    await tester.pump();
    expect(find.text('暂停'), findsOneWidget);

    source.emit(PlayerStatus.paused);
    await tester.pump();
    expect(find.text('播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('session replacement and disposal detach old status listeners', (
    tester,
  ) async {
    final oldSource = _StatusSource()..status = PlayerStatus.playing;
    final newSource = _StatusSource();
    await tester.pumpWidget(_build(oldSource));
    expect(find.text('暂停'), findsOneWidget);

    await tester.pumpWidget(_build(newSource));
    expect(oldSource.listeners, isEmpty);
    expect(newSource.listeners, hasLength(1));
    expect(find.text('播放'), findsOneWidget);

    oldSource.emit(PlayerStatus.playing);
    await tester.pump();
    expect(find.text('播放'), findsOneWidget);

    newSource.emit(PlayerStatus.playing);
    await tester.pump();
    expect(find.text('暂停'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(newSource.listeners, isEmpty);
    newSource.emit(PlayerStatus.completed);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
