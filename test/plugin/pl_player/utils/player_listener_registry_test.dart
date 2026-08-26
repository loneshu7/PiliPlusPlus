import 'package:PiliPlus/plugin/pl_player/utils/player_listener_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listener can remove itself while an event is dispatched', () {
    final registry = PlayerListenerRegistry<int>();
    final calls = <String>[];

    late PlayerListener<int> removingListener;
    removingListener = (value) {
      calls.add('removing:$value');
      registry.remove(removingListener);
    };
    registry
      ..add(removingListener)
      ..add((value) => calls.add('second:$value'))
      ..add((value) => calls.add('third:$value'))
      ..notify(1)
      ..notify(2);

    expect(calls, [
      'removing:1',
      'second:1',
      'third:1',
      'second:2',
      'third:2',
    ]);
  });
}
