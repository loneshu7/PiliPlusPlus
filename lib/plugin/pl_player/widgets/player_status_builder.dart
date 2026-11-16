import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:flutter/widgets.dart';

/// Rebuilds from the backend-neutral status stream without requiring an Rx state.
class PlayerStatusBuilder extends StatefulWidget {
  const PlayerStatusBuilder({
    super.key,
    required this.currentStatus,
    required this.addListener,
    required this.removeListener,
    required this.builder,
  });

  final PlayerStatus Function() currentStatus;
  final void Function(ValueChanged<PlayerStatus>) addListener;
  final void Function(ValueChanged<PlayerStatus>) removeListener;
  final Widget Function(BuildContext, PlayerStatus) builder;

  @override
  State<PlayerStatusBuilder> createState() => _PlayerStatusBuilderState();
}

class _PlayerStatusBuilderState extends State<PlayerStatusBuilder> {
  late PlayerStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus();
    widget.addListener(_onStatusChanged);
  }

  @override
  void didUpdateWidget(PlayerStatusBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.addListener != widget.addListener ||
        oldWidget.removeListener != widget.removeListener) {
      oldWidget.removeListener(_onStatusChanged);
      _status = widget.currentStatus();
      widget.addListener(_onStatusChanged);
    }
  }

  void _onStatusChanged(PlayerStatus status) {
    if (mounted && _status != status) {
      setState(() => _status = status);
    }
  }

  @override
  void dispose() {
    widget.removeListener(_onStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _status);
}
