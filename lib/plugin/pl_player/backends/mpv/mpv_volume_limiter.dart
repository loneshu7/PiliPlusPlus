import 'dart:math' as math;

import 'package:media_kit/media_kit.dart' show Player;

/// Applies upstream's mpv volume boost without exposing mpv to shared models.
class MpvVolumeLimiter {
  Player? _player;
  String? _alimiter;

  /// mpv 的 volume 属性是三次方曲线（`gain = (volume / 100) ^ 3`），且这层
  /// 增益直接乘在 PCM 样值上：200% 就是 8 倍（+18dB），300% 是 27 倍
  /// （+28.6dB）。B 站音频峰值本就接近满刻度，放大后越过 0dBFS 被硬削波，
  /// 听感就是粗糙、发闷、带毛刺。
  ///
  /// 这里让 mpv 的 volume 恒 <= 100，把 >100% 的增益挪进 af 滤镜链，用
  /// alimiter 自身的 level_in 放大、再限幅在 0dBFS 以内。增益按 mpv 原来的
  /// 三次方曲线换算，听感响度与旧版一致，只是不再破音。
  ///
  /// 只用 alimiter 是因为 Android 版 media_kit 自带的 libmpv 只编进了
  /// alimiter / aresample / equalizer / dynaudnorm / loudnorm 几个音频滤镜，
  /// 没有 libavfilter 的 volume 滤镜，用它会导致整条音频链初始化失败（静音）。
  ///
  /// mpv 的 af 链作用在 lavfi-complex（音频归一化）之后、实际输出之前
  /// （见 mpv 手册 --lavfi-complex 一节），两层互不冲突。
  ///
  /// [volume] 为线性倍数，1.0 即 100%
  Future<void>? setVolumeCapped(Player? player, double volume) {
    assert(volume >= 0);
    if (player == null) return null;
    if (!identical(_player, player)) {
      _player = player;
      _alimiter = null;
    }
    final boost = _boostAf(volume);
    if (boost == null) {
      if (_alimiter != null) {
        player.setProperty('af', '');
        _alimiter = null;
      }
      return player.setVolume(volume * 100);
    } else {
      // 拖动音量时增益连续变化，重建滤镜链开销偏大，
      // 增益按 0.5dB 取整，值未变化时跳过
      if (_alimiter != boost) {
        player.setProperty('af', boost);
        _alimiter = boost;
      }
      return player.setVolume(100);
    }
  }

  /// [volume] > 1.0 时返回防削波的增益滤镜串，否则返回 null。
  ///
  /// level=0 关闭 alimiter 的自动电平（不做归一化），limit=1 即 0dBFS。
  static String? _boostAf(double volume) {
    if (volume <= 1.0) return null;
    // mpv 的音量是三次方曲线：gain = v^3
    final db = (60 * math.log(volume) / math.ln10 * 2).round() / 2;
    final gain = math.pow(10, db / 20).toDouble();
    return 'alimiter=level_in=${gain.toStringAsFixed(3)}:limit=1:level=0';
  }
}
