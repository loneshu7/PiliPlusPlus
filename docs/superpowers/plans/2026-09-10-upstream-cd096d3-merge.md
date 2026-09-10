# 上游 cd096d3 合并处理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将上游截至 cd096d3 的 14 个提交按普通 merge 整体同步，解决文本冲突并让 Media3 获得上游新的进度语义。

**Architecture:** 普通功能和 UI 采用上游实现；Media3、下拉竖屏全屏和应用内小窗保留公共接口与最小挂接。先在干净同步分支完成合并、验证和审查，再集成本地发布分支。2026-09-10 用户已授权开始执行，状态以复选框和 current_state.md 为准。

**Tech Stack:** Flutter 3.47.3 / Dart 3.13.x、material_ui 1.2.0、Android Media3、media-kit、Flutter Texture、Android Gradle。

**Spec:** `AGENTS.md` 第 4–9 节、`docs/current_state.md` 的 2026-09-10 查询与冲突预演，以及用户本次“有建议怎么处理合并”的问题。

## Global Constraints

- 仅支持 Android；用户可见软件名 `pili++`，applicationId/namespace `com.shudo.plusplus`，Java/Kotlin package `com.example.piliplus`。
- 本地长期差异仅 Media3 完整替代 mpv、下拉竖屏全屏、复用会话与 Texture 的应用内小窗。
- 普通 merge 保留上游同步边界；当前建议目标固定为 `cd096d3377f3a80d17c910d732b0762f6d8588d5`，执行时若采用更新提交需重新审查增量。
- 不把整份本地播放器页面覆盖到上游，也不把 Media3 公共接口替换回直接调用 mpv；处理冲突不新增独立普通业务实现。
- 保留现有未提交文档与未跟踪 `nul`；只按明确路径暂存文件，不批量提交未知文件。
- 当前 `2.1.3+1` 仅可构建验证包；versionCode 1 低于交付基线，不作为升级交付包，不改变签名或发布基线。
- 自动化不代替真机验收；未验证的场景保持“待真机验证”。

## 已确认的输入与文件职责

- 本地 HEAD：`a5a93d7a23da38c8a0c81eeac520d6e1e7d848a4`；merge-base：`5aa7b02e3dc8d298079a126887ee3dce02bf35a1`。
- 上游改动 49 个文件，13 个与本地改动重叠；merge-tree 预演为 3 文件 / 9 个文本冲突块。
- `lib/pages/video/widgets/header_control.dart`：6 块，普通头部布局、import、Debug 空降入口与相邻格式变更。
- `lib/plugin/pl_player/controller.dart`：1 块，截图获取、保存与错误处理；同时负责两个后端的进度事件。
- `lib/plugin/pl_player/view/view.dart`：2 块，翻译选择和底部进度条；保留已有渲染与手势挂接。
- `lib/plugin/pl_player/widgets/bottom_control.dart`：上游自动合并的拖动进度条，需和手势路径使用同一组进度状态。
- `.fvmrc`、`pubspec.yaml`、`pubspec.lock`、`lib/scripts/material/scaffold.patch`、`lib/scripts/material/tabs.patch`：Flutter / material_ui 升级和补丁适配。
- `docs/current_state.md`、本计划：记录准确源码、验证结果、未完成验收与集成状态。

### Task 1: 保存起点并准备独立验证环境

**Files:** 现有两份文档、本计划；独立同步工作区中的 Flutter / pub 缓存；不编辑应用源文件。

**Interfaces:** 输入上述 Git 基线和原工作区未提交内容；输出干净的 `sync/upstream-20260910-cd096d3` 分支及 Flutter 3.47.3 工具链。

- [x] 按 using-git-worktrees 技能确认独立工作区位置与忽略规则，在同步分支保存必要文档快照；原工作区未知 `nul` 保留原样。合并只在已确认干净的同步工作区进行。
- [x] 在同步工作区记录以下命令结果，要求 HEAD 与已记录起点或仅文档快照提交一致：

```powershell
git status --short --branch
git merge-base HEAD cd096d3377f3a80d17c910d732b0762f6d8588d5
git log --reverse --oneline HEAD..cd096d3377f3a80d17c910d732b0762f6d8588d5
git diff --stat HEAD...cd096d3377f3a80d17c910d732b0762f6d8588d5
```

- [x] 准备专用于本次验证的 Flutter 3.47.3 与 pub 缓存，保留既有 3.47.2 环境以供对照。记录 `flutter --version` 和 `dart --version` 的实际输出。
- [x] 阅读目标提交的 `lib/scripts/patch.ps1`，复用其 Android 补丁清单。该脚本当前包含全局 Git 用户设置和按目录枚举删除 material_ui 缓存，不能直接在共享本地环境原样运行；在隔离目录按清单逐项 `git apply --check`、应用和反向检查，定位包目录使用 `.dart_tool/package_config.json` 的准确 rootUri。
- [x] 文档快照提交后核对同步工作区干净，记录原始未提交内容仍在原工作区安全保留。

### Task 2: 完成普通合并与必要 Media3 适配

**Files:** 三个冲突文件、自动合并的 `bottom_control.dart` 和其他上游文件；依赖与补丁文件按最终上游状态逐项核对。

**Interfaces:** `captureFrame(): Future<PlayerFeatureResult<ui.Image>>`、`position`、`seekPosition`、`progress`、`onSeekStart(int)`、`onSeekEnd()`；保留 `_positionListeners`、媒体通知和心跳事件。

- [x] 在同步工作区开始普通合并并列出实际冲突；不使用会统一选择一侧的策略参数：

```powershell
git merge --no-ff --no-commit cd096d3377f3a80d17c910d732b0762f6d8588d5
git diff --name-only --diff-filter=U
```

- [x] 视频头部的 6 处冲突采用上游 `Padding + Column` 布局、边距和 Debug 空降入口。保留现有公共轨道、字幕、播放器信息、截图及小窗相关调用。`AppBar` 包装可追溯到仓库旧基线，不将其本身视为必须保留的 Media3 能力。合并 import 后同时包含：

```dart
import 'package:flutter/foundation.dart' show compute, kDebugMode;
import 'package:material_ui/material_ui.dart' hide showBottomSheet;
```

- [x] 截图继续调用本地 `captureFrame()`，保留 `PlayerFeatureSuccess` / `PlayerFeatureUnavailable` / `PlayerFeatureFailure`、错误上报及 `whenComplete(value.dispose)`。采用上游延后计算文件名时间的改动：删除截图请求前的 `time` 声明，在 PNG 编码成功后的 `if (bytes != null)` 内、保存前放入以下代码：

```dart
final time = DurationUtils.formatDuration(
  positionInMilliseconds / 1000,
).replaceAll(':', '-');
```

- [x] 翻译菜单采用上游 `onSelected: videoDetailController.setLanguage` 与各项 `value`，移除旧菜单项中的重复 `onTap`，避免重复处理。保留现有字幕入口和 `PlPlayerSurface`，不重新引入直接读取后端对象的代码。
- [x] 底部常驻进度条和控制栏进度条统一读取 `plPlayerController.progress` / `controller.progress`；拖动更新 `seekPosition`，后端事件更新 `position`。对照 `d7c6263` 保留结束时立即更新目标位置的顺序，同时保持既有下拉、上滑、锁定及手势互斥逻辑。
- [x] 修正预演中已确认的语义遗漏：Media3 事件回调仍有 `if (!isSeeking.value)`，而 mpv 回调已按上游移除。在 Media3 回调中使用以下完整条件块，保持下方 `_positionListeners.notify(event.position)`：

```dart
final posInSeconds = event.position.inSeconds;
if (posInSeconds != position.value) {
  position.value = posInSeconds;
  videoPlayerServiceHandler?.onPositionChange(event.position);
  makeHeartBeat(posInSeconds);
}
```

- [x] 审查自动合并的直播刷新：Media3 已使用 `isLive ? Duration.zero : currentPosition` 且继承 `playWhenReady`，保持该行为；mpv 接受上游直播不携带旧位置的修复。检查新视频和小窗恢复仍分别执行正确的会话释放或接回流程。
- [x] 接受动态、评论、空降编辑、Android 外部应用打开、Linux 单实例等普通上游改动；AndroidHelper 与生成 JNI 绑定配对核对，应用身份不改。
- [x] 获取目标依赖并完成 Task 1 的补丁适配。确认 Flutter 3.47.3、material_ui 1.2.0、logger 2.8.0、platform 3.2.0 与锁文件一致，media-kit 未发生额外升级。
- [x] 确认无未合并文件、无冲突标记，检查有效源码差异后提交合并结果：

```powershell
git diff --name-only --diff-filter=U
rg -n '^(<<<<<<<|=======|>>>>>>>)' lib android
git diff --check
git diff --stat a5a93d7a23da38c8a0c81eeac520d6e1e7d848a4
```

预期未合并文件和冲突标记为空；`rg` 无匹配退出 1 属正常结果。提交信息使用 `sync: merge upstream main at cd096d3`。

### Task 3: 自动化、真机回归与集成审查

**Files:** `test/plugin/pl_player/`、`test/pages/audio/`、Android JVM 测试、构建产物、`docs/current_state.md`、本计划。

**Interfaces:** 输入准确合并提交；输出可审查的测试记录、同一源码状态的 Android 验证 APK 和真机回归结果。

- [ ] 使用 Task 1 的准确工具链运行下列检查，任一失败先定位并修复，不把失败记为已通过：

```powershell
dart format --output=none --set-exit-if-changed lib test
dart analyze
flutter test
```

- [ ] 在 `android` 目录执行 JVM 门禁，两个 `-P` 参数保持独立并加引号：

```powershell
.\gradlew.bat :app:testDebugUnitTest '-Pkotlin.incremental=false' '-Pkotlin.compiler.execution.strategy=in-process'
```

- [ ] 执行 Android Release 构建，并按 AGENTS.md 的依赖升级要求覆盖 armeabi-v7a、arm64-v8a、x86_64；构建所需非增量 Kotlin 参数沿用已有验证配置。核对应用名、applicationId、版本、ABI、签名及 SHA-256；仅保存验证产物，文件名增加上游 SHA 与 validation 标识，不覆盖正式交付包。

```powershell
flutter build apk --release --split-per-abi --no-pub
```

- [ ] 在真实 Android 设备验证拖动：实际播放 10 秒时将预览拖到 80 秒，后端报告 11 秒时实际位置为 11、预览仍为 80；结束拖动后显示和跳转至目标位置。分别检查手势、底部进度条、暂停时拖动、短拖取消、连续 seek 与媒体通知，确认两个后端的公共状态一致。
- [ ] 真机检查截图保存/取消/失败提示与评论区截图，窗口态及全屏控件可见可操作；检查翻译与字幕、直播刷新、动态三标签/分页、评论分页、空降时间编辑及“其它 app 打开”。
- [ ] 回归三类差异的关键场景：顶部下拉与短滑回弹、全屏上滑退出、锁定及横向 seek；应用内小窗同会话/Texture 恢复、打开下一视频释放旧会话、分 P / PGC / 本地媒体恢复、前后台与系统 PiP。
- [ ] 整理准确合并提交、源码改动、自动化与真机结果。未完成真机场景明确记录为待验证，不能据此宣称兼容完成；集成前重点审查新增直接 mpv 依赖和普通上游页面是否被本地旧结构覆盖。
- [ ] 验证达到约定门禁后集成本地 `release/2.1.10`；集成前重新核对原工作区文档修改，妥善保存后再合回，不覆盖原有未提交内容。推送、正式发布和版本升级另按用户实际请求执行。

## 自检结论

- 方案覆盖 3 个文本冲突文件、Media3 进度事件的自动合并遗漏，以及 Flutter/material_ui 依赖变化。
- 使用现有公共方法与测试入口，没有新增产品功能或计划中的未定义 API。
- 原建议阶段未修改应用源码；2026-09-10 用户授权后开始逐项执行，未勾选项仍待完成。
