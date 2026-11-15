import 'dart:io';

import 'package:PiliPlus/models/common/sponsor_block/segment_model.dart';
import 'package:PiliPlus/models_new/sponsor_block/segment_item.dart';
import 'package:PiliPlus/pages/sponsor_block/block_mixin.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';

class _BlockHarness extends GetxController with BlockConfigMixin, BlockMixin {
  bool ready = false;
  final positionCallbacks = <ValueChanged<Duration>>{};
  final seeks = <Duration>[];

  @override
  BlockConfigMixin get blockConfig => this;
  @override
  bool get blockPlayerReady => true;
  @override
  bool get blockPlayerPlaying => true;
  @override
  bool get blockMediaReady => ready;
  @override
  bool get autoPlay => true;
  @override
  bool get preInitPlayer => true;
  @override
  bool get isUgc => true;
  @override
  int get timeLength => 100000;
  @override
  int get currPosInMilliseconds => 0;

  @override
  void addBlockPositionListener(ValueChanged<Duration> listener) =>
      positionCallbacks.add(listener);
  @override
  void removeBlockPositionListener(ValueChanged<Duration> listener) =>
      positionCallbacks.remove(listener);
  @override
  void addBlockPlayingListener(ValueChanged<bool> listener) {}
  @override
  void removeBlockPlayingListener(ValueChanged<bool> listener) {}
  @override
  Future<void> seekTo(Duration duration) async => seeks.add(duration);
  @override
  Future<void> onSkip(SegmentModel item, {bool isSkip = true}) =>
      seekTo(Duration(milliseconds: item.segment.$2));

  void emit(int milliseconds) {
    for (final listener in positionCallbacks.toList()) {
      listener(Duration(milliseconds: milliseconds));
    }
  }

  void loadSegments() => handleSBData([
    SegmentItemModel(
      category: 'sponsor',
      segment: [2000, 10000],
      uuid: 'test-segment',
      videoDuration: 100000,
    ),
  ]);
}

void main() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('piliplus-block-test-');
    Hive.init(directory.path);
    GStorage.setting = await Hive.openBox('setting');
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('preparation events do not consume the first ready position', () {
    final block = _BlockHarness()..loadSegments();
    block.emit(3000);
    expect(block.seeks, isEmpty);
    block.ready = true;
    block.emit(3000);
    expect(block.seeks, [const Duration(seconds: 10)]);
    block.resetBlock();
    expect(block.positionCallbacks, isEmpty);
  });

  test('automatic skips begin inside the segment rather than before it', () {
    final block = _BlockHarness()
      ..ready = true
      ..loadSegments();
    block.emit(1700);
    expect(block.seeks, isEmpty);
    block.emit(2200);
    expect(block.seeks, [const Duration(seconds: 10)]);
    block.emit(3200);
    expect(block.seeks, hasLength(1));
    block.resetBlock();
  });
}
