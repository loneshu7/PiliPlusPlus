<div align="center">
  <img width="180" height="180" src="assets/images/logo/logo.png" alt="pili++ logo">
  <h1>pili++</h1>
  <p>面向 Android 的 PiliPlus 衍生版本</p>

  ![GitHub repo size](https://img.shields.io/github/repo-size/loneshu7/PiliPlusPlus)
  ![GitHub Repo stars](https://img.shields.io/github/stars/loneshu7/PiliPlusPlus)
  ![GitHub all releases](https://img.shields.io/github/downloads/loneshu7/PiliPlusPlus/total)
</div>

> [!IMPORTANT]
> `pili++` 基于开源项目
> [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)。
> 本仓库持续同步上游，只长期维护三类 Android 功能差异；其余通用产品功能以上游实现为准。

## 项目定位

`pili++` 不是独立重写全部业务功能的 fork，而是“上游 PiliPlus + 三类长期维护的 Android 差异”：

1. 使用 AndroidX Media3 ExoPlayer 完整替代 Android 上的 mpv；
2. 视频详情页下拉进入竖屏全屏、竖屏全屏上滑退出及其连续动画；
3. 复用同一播放器会话和 Flutter `Texture` 的应用内小窗。

搜索、推荐、动态、评论、账号、收藏、下载、普通 UI、业务接口等功能由上游 PiliPlus 实现。
本仓库的产品名、Android applicationId、Android-only CI、签名和发布校验属于支持上述三类差异的
工程改造，不作为额外产品功能分叉。

## Media3 迁移目标

“替代 mpv”不只是让视频能够播放。最终状态必须满足：

- 原有控件、手势、弹幕、字幕、章节、轨道、截图和业务入口保持可用；
- 播放、暂停、seek、缓冲、倍速、音量、完成、错误和换源状态正确回传 Flutter；
- 点播、DASH、直播、独立音频、本地文件及主要 UGC/PGC 场景闭环；
- 音频焦点、媒体通知、耳机/蓝牙、后台播放、应用内小窗和系统 PiP 行为一致；
- 不通过隐藏入口、空实现、最终态“暂不支持”或静默回退 mpv 掩盖缺口；
- Android APK 最终不再包含 `libmpv.so` 和无用途的 media_kit 原生组件。

Media3 继续通过 Flutter `Texture` 接入原播放器图层，不使用会遮挡 Flutter 控件的原生
`PlayerView`。详细兼容记录见
[Android ExoPlayer 兼容记录](docs/android_exoplayer.md)，完整移除计划见
[Android mpv 移除方案](docs/android_mpv_removal.md)。

## 当前状态

以下结论来自当前状态文档中记录的自动化和 Android 真机反馈，不自动覆盖所有 Android 版本、
芯片、折叠屏或后续代码修改。

| 范围 | 当前状态 |
| --- | --- |
| Media3 `Texture`、DASH 点播、直播和独立音频 | 已实现，主要流程已真机验证 |
| 控制层、播放/暂停、seek、倍速、亮度/音量和常用手势 | 已真机验证 |
| 清晰度、CDN、分P、换源状态保持和网络重载 | 已真机验证 |
| 全屏、旋转、锁定、画面适配、缩放和翻转 | 已真机验证 |
| 弹幕、字幕、bitmap/竖排字幕、章节、预览、高能进度和 SponsorBlock | 已真机验证 |
| 音视频/字幕轨道、播放器信息和当前支持的音频滤镜映射 | 已实现并有真机验证记录 |
| 音频焦点、媒体通知、媒体键、耳机/蓝牙、后台和系统 PiP | 已真机验证 |
| 普通截图、评论区截图和动态 WebP | 已真机验证 |
| 视频页下拉竖屏全屏、上滑退出和连续缩放动画 | 已真机验证 |
| 应用内小窗及其与系统 PiP 的往返 | 已真机验证 |
| 解码模式、安全缓冲、网络恢复和硬解失败后软解重试 | 已实现，仍需扩展设备与媒体矩阵 |
| Android 完整移除 mpv | 未完成 |

当前 APK 仍包含 mpv。Live Photo、公共层中的部分 media_kit 类型、Android 初始化和设置项、任意
复杂 FFmpeg 音频滤镜及部分生命周期边界仍需迁移或验收。因此现在不能宣称“mpv 已被完整替代”。
精确的 Git 基线、最近交付、已知缺口和下一步见
[当前项目状态](docs/current_state.md)。

## 三类本地功能

### 视频页下拉竖屏全屏

在视频详情内容真实位于顶部时，下拉可以跟手进入竖屏全屏；竖屏全屏视频区域上滑可以退出，
短滑会回弹。播放器尺寸、位置和详情面板由同一进度驱动，并避免影响横向 seek、纵向亮度/音量、
双击、长按、缩放和锁定等原播放器手势。评论区和详情非顶部滚动不会触发该交互。

### 应用内小窗

“设置 → 播放设置 → 应用内小窗播放”默认关闭。开启后，从正在播放的视频页返回时会把同一个
播放器和 Flutter `Texture` 平滑缩小为悬浮小窗，不重新创建媒体会话或跳转进度。

小窗按视频真实宽高比适配，支持拖动、播放/暂停、VOD 前后十秒、关闭和恢复当前视频页；应用内
小窗不显示“系统画中画”按钮。进入后台后仍可按系统规则进入 Android PiP，从 PiP 点击全屏会
恢复当前视频详情页，关闭 PiP 不会主动打开视频页。

## 上游同步

本仓库会频繁同步上游 PiliPlus。处理冲突时遵循：

- 普通业务、普通 UI 和依赖更新默认接受上游实现；
- 上游重写视频页或播放器 UI 时，接受上游新结构，再重新挂接 Media3、竖屏全屏和小窗的最小 hook；
- 不用旧本地整文件覆盖上游，也不把上游已有功能记为 `pili++` 自研；
- `pubspec.yaml`、Gradle、Manifest 和生成文件按最终语义逐项合并；
- 同步后按受影响范围回归 Media3、竖屏全屏、小窗、系统 PiP 和生命周期。

完整协作和同步规则见 [AGENTS.md](AGENTS.md)。

## 支持平台

当前只构建、测试和交付：

- Android；
- Android 平板。

仓库仍保留 iOS、macOS、Windows 和 Linux 平台目录及条件代码，以便继续同步上游，但这些平台不在
`pili++` 当前支持和发布范围内。

## 下载、安装与更新

发布包位于 [PiliPlusPlus Releases](https://github.com/loneshu7/PiliPlusPlus/releases)。

Android Release APK 的身份约定：

- 应用名称：`pili++`；
- applicationId / namespace：`com.shudo.plusplus`；
- Java/Kotlin package：`com.example.piliplus`；
- 目标 ABI：`arm64-v8a`、`armeabi-v7a`、`x86_64`；
- 后续正式包使用同一签名证书和递增的 `versionCode`，以支持覆盖安装并保留数据。

应用默认检查本仓库的 GitHub Releases，也可在设置中关闭启动检查，或从“关于 → 当前版本”手动
检查。Android 会选择匹配设备 ABI 的 APK 并交给浏览器下载；安装仍由 Android 系统确认，不会在
应用内静默安装。

请只从本仓库或可信渠道获取 APK。

## Android 本地构建

### 工具链

- Flutter `3.47.1`；
- Dart `>= 3.13.0`；
- JDK 17；
- Android SDK，项目当前 compile/target SDK 为 37。

Flutter 版本同时记录在 `.fvmrc` 和 `pubspec.yaml`。项目依赖对 Flutter SDK、`material_ui` 和
`cupertino_ui` 有兼容补丁，构建前必须执行现有 patch 流程。

### PowerShell 构建示例

```powershell
$env:GITHUB_WORKSPACE = (Get-Location).Path
$flutterCommand = (Get-Command flutter).Source
$env:FLUTTER_ROOT = Split-Path (Split-Path $flutterCommand -Parent) -Parent

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File lib/scripts/patch.ps1 -platform android

dart format --output=none --set-exit-if-changed lib test
dart analyze
flutter test --no-pub --concurrency=1

Push-Location android
./gradlew.bat :app:testDebugUnitTest
Pop-Location

flutter build apk --release --split-per-abi `
  --dart-define-from-file=pili_release.json --no-pub
```

`lib/scripts/patch.ps1` 会按项目要求准备 Flutter 和 UI 包并执行 `flutter pub get`。它要求使用 Git
形式的 Flutter SDK；不要跳过补丁后把由此产生的编译错误误判为应用源码问题。

## CI 与正式发布

GitHub Actions 的 `Build` workflow 会：

1. 应用项目补丁；
2. 检查格式、运行 `dart analyze` 和完整 Flutter 测试；
3. 构建 Android 分 ABI APK；
4. PR 构建开发包；非 PR 构建从 Secrets 写入签名材料，构建后立即清理；
5. 手动运行且提供 tag 时创建 GitHub Release，其余情况只上传 Actions artifact。

签名构建需要以下 Secrets：

- `SIGN_KEYSTORE_BASE64`；
- `KEYSTORE_PASSWORD`；
- `KEY_ALIAS`；
- `KEY_PASSWORD`。

keystore、`android/key.properties` 和所有密码均不得提交。

正式交付前必须使用项目发布门禁：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File tool/verify_release.ps1 -ApkPath <apk>
```

该脚本根据 `tool/release_baseline.json` 检查应用身份、版本、ABI 和签名。只有产物实际交付后才能
更新发布基线；`-AllowAlreadyDelivered` 仅用于审计历史产物，不能授权新交付。

## 验证原则

三类本地功能的修改和受影响的上游同步至少需要：

- 格式化、静态分析和完整 Flutter 测试；
- Android JVM 单元测试和 Release 构建；
- 适用时检查 applicationId、版本、ABI、签名和 APK SHA-256；
- 使用相同媒体进行 mpv / Media3 对照；
- 回归普通窗口、全屏、竖屏下拉、应用内小窗、系统 PiP 和适用的前后台场景。

自动化通过不能替代真机验证。未执行的场景必须明确标记为“待真机验证”。

## 项目文档

- [协作约定与上游同步规则](AGENTS.md)
- [当前项目状态](docs/current_state.md)
- [Android ExoPlayer 兼容记录](docs/android_exoplayer.md)
- [Android mpv 移除方案](docs/android_mpv_removal.md)
- [发布校验工具说明](tool/README.md)

## 仓库与上游

- 当前仓库：[loneshu7/PiliPlusPlus](https://github.com/loneshu7/PiliPlusPlus)
- 直接上游：[bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
- 原始项目：[guozhigq/pilipala](https://github.com/guozhigq/pilipala)
- 相关上游：[orz12/PiliPalaX](https://github.com/orz12/PiliPalaX)

提交问题前请先搜索 [现有 Issues](https://github.com/loneshu7/PiliPlusPlus/issues)。

## 声明

本项目仅用于学习和测试，不提供任何破解内容。项目使用的接口资料均来自公开渠道。使用者应遵守
所在地区法律法规、哔哩哔哩用户协议及相关内容版权要求。

## 致谢

- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) 及其所有贡献者
- [AndroidX Media3](https://developer.android.com/media/media3)
- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [media-kit](https://github.com/media-kit/media-kit)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [dio](https://pub.dev/packages/dio)

## 许可证

本项目依据 [GNU General Public License v3.0](LICENSE) 发布。

## 上游 Star History

<a href="https://star-history.dera.page/#bggRGjQaUbCoE/PiliPlus&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date" />
   <img alt="PiliPlus Star History Chart" src="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date" />
 </picture>
</a>
