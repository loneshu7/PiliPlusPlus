# Android 完整替换并移除 mpv 开发文档

> 状态基线：2026-08-25，运行时代码提交
> `15f9e2e5bddcead114945a5f76494cdc1374212c`，状态文档提交
> `78e077b8341b5994b2116e3660799e4d08a0017e`。
>
> 本文描述从当前状态继续开发，直到 Android 版完全由 AndroidX Media3
> ExoPlayer 承担音视频播放，并从 Android APK 中移除 mpv 的实施方案。
> 历史实现与逐批验收记录见 `docs/android_exoplayer.md`，长期产品门槛见
> `AGENTS.md`，随开发变化的事实见 `docs/current_state.md`。

## 1. 目标与范围

本文的“完整替换”只针对当前正式交付平台 Android，必须同时满足产品、代码和产物
三个层面的条件：

1. Android 上所有原来由 mpv 完成的用户流程都由 Media3、Flutter 公共层或等价实现闭环；
2. Android 运行时不再创建、调用或回退到 `media_kit`/`NativePlayer`；
3. Android 设置中不再提供切回 mpv 的开关，也不保留只对 Android mpv 有效的入口；
4. Android APK 不包含 `libmpv.so`，且没有会加载 mpv 的插件或初始化代码；
5. 删除 mpv 后，点播、直播、独立音频、Live Photo、截图、动态 WebP、字幕、轨道、
   小窗、PiP、后台播放和异常恢复均通过自动化与真机验收；
6. 不以隐藏入口、静默忽略、提示“请切回 mpv”或发生错误后回退 mpv 作为完成方式。

当前项目决定是只构建、测试和交付 Android，但暂不删除 iOS、macOS、Windows、Linux
目录和条件代码。因此必须区分：

- **Android 产品完成**：Android 只使用 Media3，APK 中没有 `libmpv.so`；
- **全仓库删除 media_kit**：所有平台都不再使用 `media_kit`。这会使非 Android 播放器也
  需要迁移，超出当前 Android-only 决定，必须另行取得用户授权。

本文默认采用“Android 产品完成、非 Android mpv 代码隔离保留”的路线。若以后决定正式
退役所有非 Android 平台，可在最后直接删除全部 `media_kit` 包和适配器，流程会更简单。

## 2. 当前结论

当前版本已经具备 Media3 默认播放和大部分 mpv 等价能力，但**还不能直接删除 mpv**。

已经过当前测试设备验证的主要 Media3 能力包括：

- 点播、直播和独立音频；
- 控制层、播放/暂停、跳转、倍速、亮度/音量及常用手势；
- 清晰度、CDN、分P和重试时的状态保持；
- 全屏、旋转、锁定、画面适配、缩放和翻转；
- 弹幕、B 站/外部字幕、bitmap cue、竖排字幕、章节、预览、高能进度和 SponsorBlock；
- 音视频/字幕轨选择、播放器信息和当前已支持的音频滤镜映射；
- 音频焦点、媒体通知、媒体键、耳机/蓝牙控制和后台/息屏播放；
- 应用内小窗、系统 PiP 以及二者之间的恢复流程；
- 普通截图、评论区截图和动态 WebP；
- Media3 GPU Lanczos 超分辨率、缓冲策略和解码失败软解回退实现。

仍阻止删除 mpv 的项目包括：

- Android 图片浏览器的 Live Photo 视频仍直接创建 `media_kit Player`；
- 主播放器、独立音频和 SponsorBlock 公共层仍暴露 `Player`、`VideoController`、
  `NativePlayer` 等 mpv 类型；
- 公共字幕配置和渲染层仍借用 `media_kit_video` 的
  `SubtitleViewConfiguration`、`SubtitleView` 和 `SimpleVideo`；
- 动态 WebP 工厂仍编译并保留直接调用 libmpv FFI 的 `MpvConvertWebp`；
- `main.dart` 仍无条件执行 `MediaKit.ensureInitialized()`，并在运行信息中读取
  `NativePlayer.apiVersion`；
- Android 设置仍允许关闭 Media3，并保留 `mpv 自动同步`、`mpv 视频同步` 等入口；
- 任意 FFmpeg 音频滤镜链、多响度阶段及部分 equalizer 参数还没有 Media3 等价结果；
- 具体硬解模式和软解回退仍需完成多编码、直播、本地文件、小窗、PiP、后台和不同芯片的
  真机矩阵；
- 最新播放信息弹窗修复仍待在 ExoPlayer/mpv、普通窗口/全屏中完成同机复测。

## 3. 当前依赖清单

### 3.1 直接代码依赖

| 文件 | 当前 mpv/media_kit 依赖 | 移除要求 |
| --- | --- | --- |
| `lib/plugin/pl_player/controller.dart` | 同时持有 `Player`、`VideoController` 和 `ExoPlayerController`，大量 `useExoPlayer` 分支 | 将 Android 后端固定为 Media3；mpv 逻辑移入非 Android adapter，公共控制器不暴露 mpv 类型 |
| `lib/pages/audio/controller.dart` | Android 可选 Media3，其他情况创建 `Player` | Android 固定使用 Media3；非 Android 实现隔离 |
| `lib/common/widgets/image_viewer/gallery_viewer.dart` | Live Photo 直接 `Player.create()` 和 `VideoController.create()` | 新增轻量 Media3 Texture 会话，完成打开、暂停、换图和释放 |
| `lib/pages/sponsor_block/block_mixin.dart` | 默认监听接口使用 `Player` 及其 stream | 改成后端中立的位置/播放状态订阅接口 |
| `lib/plugin/pl_player/widgets/player_surface.dart` | mpv 分支使用 `SimpleVideo` | Android Surface 只保留 `ExoPlayerView`；mpv Surface 移入非 Android adapter |
| `lib/plugin/pl_player/widgets/player_subtitle_layer.dart` | mpv 分支使用 `SubtitleView` | Android 只保留公共/Media3 字幕层；mpv 字幕层隔离 |
| `lib/plugin/pl_player/exo_player/exo_subtitle_view.dart` | Media3 字幕仍复用 `SubtitleViewConfiguration` | 在项目内建立后端中立字幕样式模型，移除 `media_kit_video` 类型 |
| `lib/plugin/pl_player/widgets/mpv_convert_webp.dart` | 直接调用 libmpv FFI 和 `NativePlayer.mpv` | Android 构建不得引用；保留时必须位于非 Android adapter |
| `lib/plugin/pl_player/widgets/player_animated_webp_converter.dart` | 在 Media3/mpv converter 之间选择 | Android 工厂固定返回 `ExoConvertWebp`；非 Android 工厂隔离 |
| `lib/main.dart` | 初始化 MediaKit，读取 mpv API 版本 | Android 不初始化或读取 mpv；运行信息显示 Media3 版本/能力 |
| `lib/pages/setting/models/video_settings.dart` | Media3 开关和 mpv 专属设置 | 删除 Android 后端开关；删除或仅在非 Android 显示 mpv 专属项 |
| `lib/utils/storage_key.dart`、`storage_pref.dart` | 保存 `useExoPlayer` 及 mpv 参数 | 做兼容读取和一次性迁移，不能粗暴删除用户设置数据 |

测试代码中 `test/plugin/pl_player/exo_player/exo_subtitle_cue_test.dart` 也直接导入
`media_kit_video`。公共字幕模型迁移后，测试必须改为项目自有类型，以确保 Media3 测试不再
因为 mpv 包才可编译。

### 3.2 Dart 包依赖

`pubspec.yaml` 当前直接依赖：

- `media_kit`；
- `media_kit_video`；
- `media_kit_libs_video`。

`media_kit_libs_video` 是全平台聚合包，会传递依赖：

- `media_kit_native_event_loop`；
- `media_kit_libs_android_video`；
- iOS、macOS、Windows、Linux 的对应原生包。

当前 `dependency_overrides` 还直接锁定了 Android、iOS、Windows 和其他 media_kit 组件。
只从业务代码删除 `Player.create()` 并不会自动从 APK 删除 libmpv；包图也必须修改。

### 3.3 当前 APK 证据

对已交付的
`pili++-2.1.9-2026082501-arm64-v8a-release-player-info-dialog-fix-final.apk`
检查 ZIP 条目，仍可看到：

```text
lib/arm64-v8a/libmedia_kit_native_event_loop.so
lib/arm64-v8a/libmpv.so
```

所以“Android 已默认使用 Media3”和“Android 已移除 mpv”是两个不同状态。最终完成时必须对
每个交付 ABI 重复此检查。

## 4. 目标架构

Android 最终结构应为：

```text
视频页 / 直播页 / 音频页 / Live Photo / 小窗
                    |
          后端中立 Flutter 控制接口
                    |
       Android Media3 controller/adapter
                    |
 MethodChannel + EventChannel + TextureRegistry
                    |
       ExoPlayerPlugin / Media3 ExoPlayer
```

非 Android 若继续保留 mpv，应位于清晰的独立边界：

```text
后端中立 Flutter 控制接口
        |                         |
Android Media3 adapter     non-Android mpv adapter
```

必须遵守以下边界：

- 页面、业务、控件、手势、弹幕、字幕、章节和 SponsorBlock 不导入 `media_kit`；
- 公共模型不使用 `PlayerState`、`VideoController`、`SubtitleViewConfiguration` 等第三方类型；
- Android adapter 不导入 `media_kit`，不创建 `NativePlayer`，不包含 mpv FFI；
- mpv adapter 不得被 Android 工厂实例化；
- Media3 继续通过 Flutter `Texture` 渲染，不改用会遮挡 Flutter 控件的 `AndroidView` 或
  原生 `PlayerView`；
- 原生 Kotlin 层负责媒体会话、媒体源、轨道、Surface、生命周期、音频处理和事件；
- Flutter 控制器负责把原生状态映射到既有 `PlPlayerController` 语义。

建议建立以下接口或等价结构，名称可按实现调整：

```dart
abstract interface class PlayerBackend {
  Stream<PlayerEvent> get events;
  PlayerSnapshot get snapshot;

  Future<void> open(PlayerMediaRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> selectTrack(PlayerTrackSelection selection);
  Future<CapturedFrame> captureFrame();
  Future<void> dispose();
}
```

`PlayerSnapshot`、`PlayerEvent`、`PlayerMediaRequest`、字幕样式、轨道和错误必须是项目自有模型。
Android Media3 与非 Android mpv 只能在 adapter 内做类型转换。

## 5. 分批实施方案

每一批都必须可独立验证。不得在一个提交中同时重构所有播放器接口、删除依赖并修改发布
配置，否则出现黑屏、音频或生命周期回归时无法定位边界。

### 批次 R0：冻结基线和产品决定

开始代码删除前完成：

1. 固定一个删除前基线提交和已签名 APK；
2. 保存 APK 的 applicationId、版本、ABI、签名和 SHA-256；
3. 使用同一批测试媒体记录 mpv 与 Media3 当前行为；
4. 明确非 Android 平台采用“隔离保留”还是“正式退役”；
5. 明确任意 FFmpeg 自定义滤镜的等价方案，不能在删除 mpv 后静默失效；
6. 收集至少 AVC、HEVC、AV1、HDR、DASH、HLS、本地文件、直播和独立音频样本；
7. 把播放信息弹窗和具体硬解模式剩余真机项先验收，避免删除基线后失去对照。

R0 完成前不得删除开关或依赖。

### 批次 R1：消除公共层的 media_kit 类型

目标是让 Media3 路径独立编译和测试，不再借用 mpv 包的类型。

实施项：

1. 新增项目自有字幕配置，例如 `PlayerSubtitleStyle`，覆盖：
   - 字体、字号、颜色、背景、描边和阴影；
   - padding、位置、对齐和拖动；
   - bitmap cue、竖排和 `text-combine-upright` 所需信息；
2. 将 `ExoSubtitleView` 改用项目自有配置；
3. 将 mpv 的 `SubtitleViewConfiguration` 转换移入 mpv adapter；
4. 把 `SimpleVideo`、`SubtitleView` 分支从公共 widget 移入 mpv adapter；
5. 将 SponsorBlock 的默认 `Player` stream 改成：
   - `addBlockPositionListener`；
   - `addBlockPlayingListener`；
   - 对应 remove 方法；
   公共 mixin 不再声明 `Player? get player`；
6. 将轨道、播放器信息、播放状态和错误继续统一为项目自有模型；
7. 更新测试，Media3 测试不得导入 `media_kit` 或 `media_kit_video`。

验收：

```text
lib/plugin/pl_player/exo_player/**  不含 package:media_kit*
公共 models/widgets/mixins          不含 Player/NativePlayer/VideoController
Media3 定向测试                     全部通过
```

### 批次 R2：迁移 Live Photo

这是当前 Android 上仍会实际创建 mpv 会话的独立用户流程。

建议新增轻量 `InlineMedia3Controller`，或允许现有 `ExoPlayerController` 创建不注册视频页业务
回调的独立会话。它应支持：

- 使用 `TextureRegistry.SurfaceProducer` 显示短视频；
- 打开网络 URL，并保留必要 headers；
- 自动播放、暂停、循环和完成状态；
- 图片左右切换时暂停旧内容并打开新内容；
- 快速滑动时以 generation/session ID 忽略旧回调；
- 页面销毁、路由退出和应用进入后台时可靠释放；
- 保持 Live Photo 图片缩放、拖动、分享和保存视频的现有交互；
- 不占用或污染视频详情页、直播、独立音频和应用内小窗的 Media3 会话。

需要补充：

- 控制器单元测试：连续换图、旧事件、重复释放、失败重试；
- widget 测试：Live Photo 与普通图片切换；
- 真机测试：单张/多张、横竖屏、前后台、弱网、页面快速关闭、连续进入退出；
- 会话泄漏检查：退出图片浏览器后没有残留通知、音频焦点、声音或 Texture。

R2 完成后，Android 图片浏览器不得调用 `Player.create()`。

### 批次 R3：Android 强制 Media3

R1、R2 完成并通过真机后，才将 Android 后端固定为 Media3。

实施项：

1. Android 的后端策略固定返回 Media3，不再读取 `Pref.useExoPlayer`；
2. 删除 Android 设置中的“使用 Android Media3 播放视频”开关；
3. 保留一次兼容迁移：旧 `useExoPlayer=false` 用户升级后也使用 Media3；
4. 主播放器 Android 路径不再持有 `_videoPlayerController`、`_videoController`；
5. 独立音频 Android 路径不再持有 `Player`；
6. Android 动态 WebP 工厂固定使用 `ExoConvertWebp`；
7. `main.dart` 在 Android 不执行 `MediaKit.ensureInitialized()`，也不读取
   `NativePlayer.apiVersion`；
8. 播放信息的 Backend 固定显示 Media3，并保留 Decoder、Renderer、PlaybackConfig、
   VideoOutput 和错误诊断；
9. 错误只进入 Media3 重试、软件解码回退或终态提示，不存在 mpv 回退；
10. 打开新视频、直播或音频前，继续按既有规则释放旧应用内小窗/会话。

若保留非 Android mpv，推荐把原逻辑移到 `backends/mpv/`，而不是继续把大量 `else` 留在
`PlPlayerController` 中。

### 批次 R4：关闭最后的行为差异

删除 mpv 前必须处理以下语义差异。

#### 音频滤镜

当前 Media3 已支持音量、`loudnorm`、`dynaudnorm`、highpass、lowpass、peaking equalizer
和 shelf 等映射，但以下情况仍不等价：

- 任意 FFmpeg 自定义滤镜；
- 多个响度阶段；
- 未支持的 equalizer width/type；
- 复杂阶段顺序或 Media3 PCM processor 无法表达的滤镜。

可接受方案只有：

1. 在 Media3 `AudioProcessor` 中实现等价 DSP；
2. 引入不会重新带回 mpv 的独立 Android DSP/FFmpeg 音频处理层；
3. 经用户明确决定，用另一个可见且可验证的功能替代，并迁移旧设置。

“播放原音并提示未适配”可以作为迁移期行为，但不满足最终 mpv 等价门槛。

#### 解码器和缓冲

必须完成：

- 硬解开/关和具体 Android MediaCodec 模式；
- AVC、HEVC、AV1、DASH 独立音视频、本地文件和直播；
- 解码失败自动切软件解码，位置、播放意图、字幕和超分状态不丢失；
- 网络/源错误不误触发解码回退；
- 安全缓冲策略不重现 Samsung Android 16 全黑回归；
- `PlaybackConfig` 与实际 Decoder/Renderer 信息一致。

#### 生命周期

覆盖普通窗口、全屏、旋转、锁屏、后台、息屏、应用内小窗、系统 PiP、耳机/蓝牙、来电/音频
焦点、快速切视频、连续 A→B→C 路由、进程被系统回收后的当前既定范围。

进程死亡后的任务恢复目前按用户决定延期。文档和发布说明必须继续明确该决定，不能把未测项
写成已完成。

### 批次 R5：删除 Android mpv 包和原生库

功能切换通过后再修改包图。

在保留非 Android mpv 的路线下：

1. 从根包删除 `media_kit_libs_video` 全平台聚合依赖；
2. 删除 `media_kit_libs_android_video` override；
3. 按仍需支持的平台显式添加 iOS、macOS、Windows、Linux 原生包；
4. 保留 `media_kit`/`media_kit_video` 仅用于非 Android adapter；
5. 若 `media_kit_video` 的 Android plugin 仍被自动注册但已无用途，使用项目内 federated
   adapter/fork 移除其 Android platform 声明，不能重新引入 libmpv；
6. 重新执行 `flutter pub get`，人工审查 `pubspec.lock` 和生成的 plugin registrant；
7. 构建每个 Android ABI 并检查 APK 内容。

如果用户决定正式退役所有非 Android 播放器，则应直接删除：

- `media_kit`；
- `media_kit_video`；
- `media_kit_libs_video`；
- 所有 `media_kit_libs_*` 与 `media_kit_native_event_loop` override；
- mpv adapter、`MpvConvertWebp` 和所有相关 import。

禁止只在 Gradle 中排除 `libmpv.so`、但保留 Android 运行时仍可能调用 `Player.create()`；这会把
明确依赖变成运行时崩溃。

### 批次 R6：删除死代码和设置债务

包图移除后执行机械清理：

- 删除 Android 的 `useExoPlayer` 分支与开关；
- 删除 Android mpv 创建、监听、轨道映射、截图、WebP 和 Surface 代码；
- 删除 Android mpv API 版本显示；
- 删除或仅在非 Android 显示 `mpv 自动同步`、`mpv 视频同步`；
- 把“开启硬解”“硬解模式”“缓冲大小”等文案改成 Media3 的实际语义；
- 保留旧 storage key 的兼容读取期，不立即删除 Hive 中的历史值；
- 更新 README、设置说明、隐私/许可证和第三方组件清单；
- 删除已经没有调用点的 patch、checksum 和 CI 下载逻辑，但不得误删非 Android 所需内容。

完成后，Android 业务代码中的 `if (useExoPlayer)` 不应再存在。后端选择只允许出现在明确的
平台 adapter 工厂中。

### 批次 R7：完整验证与正式交付

R7 必须在准确待发布源码上重新执行，不能复用删除前的结果。

自动化最低要求：

```powershell
# 固定项目工具链，并先运行仓库要求的 Flutter/material_ui patch 流程
flutter pub get
dart format --output=none --set-exit-if-changed lib test
dart analyze
flutter test --no-pub --concurrency=1

Set-Location android
./gradlew.bat :app:testDebugUnitTest
Set-Location ..

flutter build apk --release --split-per-abi `
  --dart-define-from-file=pili_release.json --no-pub
```

必须继续使用项目发布校验：

```powershell
$apkPath = "build/app/outputs/flutter-apk/pili++-<version>-<abi>-release.apk"
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File tool/verify_release.ps1 -ApkPath $apkPath
```

每个 ABI 的 APK 内容检查示例：

```powershell
Add-Type -AssemblyName System.IO.Compression.FileSystem
$apkPath = "build/app/outputs/flutter-apk/pili++-<version>-<abi>-release.apk"
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $apkPath))
try {
  $forbidden = $zip.Entries | Where-Object {
    $_.FullName -match '(?i)(libmpv|media_kit_native_event_loop)'
  }
  if ($forbidden) {
    $forbidden.FullName
    throw 'Android APK still contains mpv/media_kit native artifacts'
  }
} finally {
  $zip.Dispose()
}
```

至少还应检查：

```text
git grep -n "Player.create(" -- lib
git grep -n "NativePlayer" -- lib
git grep -n "package:media_kit" -- lib
git grep -n "useExoPlayer" -- lib
```

若保留非 Android adapter，上述搜索可以在 adapter 目录有结果，但 Android 页面、业务、公共模型、
Media3 adapter 和 Android 初始化路径必须为零；审查时不能只看总数。

## 6. 真机验收矩阵

### 6.1 媒体类型

| 分组 | 必测内容 |
| --- | --- |
| UGC/PGC | 短视频、长视频、分P、合集、课程、番剧剧集、互动视频 |
| 编码 | AVC、HEVC、AV1；设备支持时覆盖 HDR/高帧率 |
| 封装/协议 | DASH 独立音视频、HLS、普通 HTTP、本地文件、`content://` |
| 直播 | 横屏、竖屏、方形；不同清晰度、线路、CDN、音频模式 |
| 独立音频 | 直接 URL、列表、UGC 分段、起播位置、循环和上下首 |
| 边缘媒体 | Live Photo、bitmap 字幕、竖排 WebVTT、多轨本地文件 |

### 6.2 操作与状态

每种适用媒体至少覆盖：

- 首开、播放、暂停、继续、完成、回放和循环；
- 进度条、前后十秒、精确 seek、连续快速 seek；
- 清晰度、CDN、分P、剧集、音频/视频/字幕轨切换；
- 倍速、播放器音量、静音、音量均衡和支持的滤镜；
- 控制层、双击、长按、横向进度、纵向音量/亮度；
- 普通窗口、横竖屏全屏、锁定、旋转、缩放、适配和翻转；
- 弹幕、字幕、章节、预览、高能进度和 SponsorBlock；
- 截图、评论区截图、动态 WebP、分享和保存；
- 应用内小窗、系统 PiP、小窗进入 PiP、PiP 全屏恢复；
- 前后台、息屏、媒体通知、耳机/蓝牙键、音频焦点；
- 断网恢复、HTTP 失败、解码失败、快速关闭和重新进入。

### 6.3 设备覆盖

至少包括：

- 当前回归设备 Samsung SM-S9180 / Android 16；
- 一台不同厂商/SoC 的 Android 设备；
- 项目最低支持 Android 版本附近的设备或真机等价测试；
- 可用时覆盖高通、联发科或其他不同 MediaCodec 实现；
- 折叠屏/平板若无法取得设备，必须保留为明确未验证项。

## 7. 删除门槛与检查清单

只有以下各项全部满足，才可以在 Android 发布说明中写“mpv 已被 Media3 完整替代”：

### 产品行为

- [ ] Android 所有视频、直播、独立音频和 Live Photo 都使用 Media3；
- [ ] 所有原 mpv 用户入口仍存在并产生等价结果；
- [ ] 没有“暂不支持”、隐藏入口、空实现或静默 mpv 回退；
- [ ] 错误提示可理解，日志包含 session、媒体源阶段和 Media3 原因；
- [ ] 最新代码上的真机矩阵通过。

### 代码边界

- [ ] Android 页面和业务不导入 `media_kit`；
- [ ] Android/公共模型不出现 `NativePlayer`、`Player`、`VideoController`；
- [ ] Media3 字幕和 Surface 不依赖 `media_kit_video` 类型；
- [ ] SponsorBlock、截图、WebP、轨道和播放信息使用公共接口；
- [ ] Android 不再读取 `Pref.useExoPlayer`；
- [ ] Android 不初始化 MediaKit，也不调用 mpv FFI；
- [ ] 非 Android mpv 代码已隔离，或经授权后删除。

### 构建产物

- [ ] `pubspec.lock` 不再包含 Android mpv 原生包；
- [ ] Android plugin registrant 不注册 mpv 原生库加载链；
- [ ] 所有目标 ABI 的 APK 均不包含 `libmpv.so`；
- [ ] 不含无用途的 `libmedia_kit_native_event_loop.so`；
- [ ] applicationId、应用名、versionName、versionCode、ABI 和签名全部通过发布脚本；
- [ ] APK SHA-256、源码提交和构建时间已记录；
- [ ] `versionCode` 高于所有既有交付包。

### 自动化与文档

- [ ] 格式化、静态分析、全量 Flutter 测试通过；
- [ ] Android Kotlin/JVM 单元测试通过；
- [ ] Android Release 构建通过；
- [ ] `docs/android_exoplayer.md` 更新最终兼容结论；
- [ ] `docs/current_state.md` 更新 Git、验证、交付和剩余风险；
- [ ] README 和设置说明不再把 mpv 描述为 Android 可选后端；
- [ ] 未验证项没有被写成已完成。

## 8. 推荐提交顺序

建议保持以下提交边界，便于审查和回滚：

1. `refactor: introduce backend-neutral subtitle and playback models`
2. `refactor: isolate non-Android mpv adapter`
3. `feat: migrate Android live photos to Media3 texture playback`
4. `refactor: make Media3 the only Android playback backend`
5. `feat: close remaining Media3 filter and decoder compatibility gaps`
6. `build: remove Android mpv native libraries`
7. `test: cover Media3-only Android playback and lifecycle`
8. `docs: record Android mpv removal acceptance and delivery`

每个提交之后都至少运行定向测试和 `git diff --check`。涉及原生会话、Surface、音频焦点或包图的
提交还必须单独完成 Android Release 构建，不能等到最后一起发现问题。

## 9. 回滚策略

删除阶段仍应保持可诊断、可回滚：

- 不使用运行时静默回退 mpv；回滚通过 Git 提交和独立审计 APK 完成；
- 每一批保留准确 commit、APK SHA-256、签名和真机结果；
- 若出现全黑、无声、Texture 泄漏或后台会话残留，先回滚最近的单一批次，不把多个策略一起
  恢复；
- 包图删除前保留最后一个已签名 mpv/Media3 双后端基线包，仅用于对照，不作为新交付；
- 正式 Media3-only 包必须提高 `versionCode`，确保可以从最近正式包直接覆盖安装；
- 不更换 applicationId、Java/Kotlin package、数据目录或签名证书。

## 10. 当前建议的下一步

从风险和依赖顺序看，下一批应从 **R1 公共类型解耦** 开始，而不是直接改 `pubspec.yaml`。

第一组最小闭环建议为：

1. 新建项目自有字幕配置模型；
2. 让 `ExoSubtitleView` 和相关测试不再导入 `media_kit_video`；
3. 把 mpv 字幕配置转换限制在 mpv adapter；
4. 将 SponsorBlock 的 `Player` 默认监听改为公共回调接口；
5. 运行完整 Flutter 测试和 Android Release 构建；
6. 在真机回归普通/bitmap/竖排字幕、拖动和 SponsorBlock。

这组完成后再迁移 Live Photo。只有 Live Photo、公共类型和剩余真机差异全部关闭，才进入
Android 强制 Media3 与原生依赖删除阶段。
