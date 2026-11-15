part of 'package:PiliPlus/pages/live_room/controller.dart';

mixin _LiveSizeMixin on GetxController, _LiveDataMixin {
  void _onSizeChanged(Size value) {
    final isVertical = value.height > value.width;
    isPortrait.value = isVertical;
    plPlayerController.isVertical = isVertical;
  }

  void _startSizeSub() {
    if (isPortrait.value) return;
    _stopSizeSub();
    plPlayerController.addVideoSizeListener(_onSizeChanged);
  }

  void _stopSizeSub() {
    plPlayerController.removeVideoSizeListener(_onSizeChanged);
  }

  @override
  void onClose() {
    _stopSizeSub();
    super.onClose();
  }
}
