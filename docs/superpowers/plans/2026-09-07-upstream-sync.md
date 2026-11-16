# 上游同步实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 合入 upstream/main@5aa7b02 的两个提交并验证 Android 构建。
**Architecture:** 在临时 sync 分支普通 merge，接受上游普通功能，保留本地后端隔离和应用身份；自动化通过后 ff-only 合回本地发布分支。
**Tech Stack:** Flutter 3.47.2、Dart 3.13.2、Android Gradle、media-kit、Media3。
**Spec:** AGENTS.md 与用户本次“拉取”指令。

## Global Constraints
- 仅同步上游，不推送、不交付 APK、不修改签名或版本。
- applicationId/namespace 保持 com.shudo.plusplus；Media3、下拉交互、小窗保持本地语义。
- 自动化不替代真机验收。当前 versionCode 1 低于交付基线，不作为升级包。

## Task 1: 保存起点并合入
**Files:** docs/current_state.md、本计划；上游的收藏夹三个文件、迁移后的 mpv_convert_webp.dart、pubspec.yaml、pubspec.lock。
- [x] 核对 fetch、HEAD、merge-base、双方提交和重叠文件。
- [x] 创建 sync/upstream-20260907-5aa7b02，提交状态文档和计划。
- [x] 执行 git merge --no-ff upstream/main，审查六个有效改动文件和重命名映射。

## Task 2: 审查依赖并验证
**Files:** 不主动新增本地业务差异；日志保存 build/sync-5aa7b02-logs/。
- [ ] flutter pub get，比较 media-kit 旧 08b7b94 与新 73771ec 的接口、事件循环、WebP 调用兼容。
- [ ] dart format --output=none --set-exit-if-changed lib test。
- [ ] dart analyze 与 flutter test；运行配置可用的 LSP 诊断。
- [ ] Android :app:testDebugUnitTest 和 :app:assembleRelease，沿用既有 Kotlin 非增量/in-process 参数。
- [ ] git diff --check 并审查合并结果；若失败保持同步分支并记录阻塞，不宣称完成。

## Task 3: 本地集成与交接
**Files:** docs/current_state.md、本计划。
- [ ] 记录准确提交、依赖审查、自动化结果与真机待验项目。
- [ ] 自动化通过后提交文档，git switch release/2.1.10 && git merge --ff-only sync/upstream-20260907-5aa7b02。
- [ ] 核对工作区和相对 upstream/main 的计数；不推送、不交付、不更新发布基线。
