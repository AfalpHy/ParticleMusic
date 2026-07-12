# ReplayGain 元数据与全部播放路径 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从标准音频标签读取、缓存并选择 ReplayGain，在普通输出与 USB 独占请求中使用同一有效增益。

**Architecture:** 扩展现有 `audio_tags_lofty` FFI 暴露四个数值字段，主项目将字段持久化到 Drift。纯 Dart 函数完成标签同源回退与 Peak 防削波；播放器和 USB 请求只消费计算结果，不分别解释标签。

**Tech Stack:** Rust Lofty 0.24、Dart FFI、Flutter、Drift、media_kit/libmpv、flutter_test。

---

## 文件映射

- 外部依赖修改：`audio_tags_lofty/rust/lofty_ffi/src/lib.rs`、`audio_tags_lofty/rust/lofty_ffi/tests/main.rs`、`audio_tags_lofty/lib/src/loffy_ffi.dart`、平台原生库。
- 主项目元数据：`lib/base/my_audio_metadata.dart`、`lib/base/data/database.dart`、`lib/base/data/database.g.dart`、`lib/base/extensions/metadata_extension.dart`、`lib/base/services/dsd_metadata.dart`。
- 增益与偏好：新建 `lib/base/services/replay_gain.dart`，修改 `lib/base/services/usb_audio_preferences.dart`。
- 播放接入：`lib/base/audio_handler.dart`、`lib/base/services/usb_audio_service.dart`。
- 设置界面：`lib/layer/audio_output_settings_layer.dart`、`lib/layer/layers_manager.dart`、中英文 ARB 与生成文件。
- 测试：新建 `test/replay_gain_test.dart`、`test/metadata_database_test.dart`，修改现有 USB 偏好、服务和 DSD 元数据测试。

### Task 1: 扩展 audio_tags_lofty ReplayGain FFI

**Files:**
- Modify: `rust/lofty_ffi/src/lib.rs`
- Modify: `rust/lofty_ffi/tests/main.rs`
- Modify: `lib/src/loffy_ffi.dart`
- Modify: `pubspec.yaml`
- Create: `.github/workflows/build-native.yml`

- [ ] **Step 1: 获得外部仓库写入位置**

在用户明确授权创建 GitHub fork 后执行：

```powershell
gh repo fork AfalpHy/audio_tags_lofty --clone=false --remote=false
git clone https://github.com/huya688zdx/audio_tags_lofty.git F:\Symusic\audio_tags_lofty
git -C F:\Symusic\audio_tags_lofty switch -c replaygain-metadata origin/main
```

预期：创建 `huya688zdx/audio_tags_lofty`，本地分支为 `replaygain-metadata`。依赖提交并推送后删除本地克隆，避免保留第二开发目录。

- [ ] **Step 2: 写 Rust 解析失败测试**

在 `rust/lofty_ffi/src/lib.rs` 的测试模块加入可直接测试的解析器：

```rust
fn parse_replay_gain(value: Option<&str>) -> f64 {
    value
        .and_then(|value| value.trim().trim_end_matches("dB").trim().parse().ok())
        .unwrap_or(f64::NAN)
}

#[cfg(test)]
mod replay_gain_tests {
    use super::parse_replay_gain;

    #[test]
    fn parses_gain_and_peak_values() {
        assert_eq!(parse_replay_gain(Some("-7.23 dB")), -7.23);
        assert_eq!(parse_replay_gain(Some("0.9876")), 0.9876);
        assert!(parse_replay_gain(Some("invalid")).is_nan());
        assert!(parse_replay_gain(None).is_nan());
    }
}
```

- [ ] **Step 3: 运行测试确认失败**

```powershell
cargo test --manifest-path rust\lofty_ffi\Cargo.toml replay_gain_tests
```

预期：FAIL，因为 `parse_replay_gain` 尚未存在于生产实现位置。

- [ ] **Step 4: 实现 FFI 字段**

在 `LoftyMetadata` 末尾、`picture` 之前保持 Rust 与 Dart 相同顺序加入四个 `f64`：

```rust
pub replay_gain_track_gain_db: f64,
pub replay_gain_track_peak: f64,
pub replay_gain_album_gain_db: f64,
pub replay_gain_album_peak: f64,
```

增加读取函数并在 `lofty_read_metadata` 初始化结构体时调用：

```rust
fn replay_gain(tag: Option<&Tag>, key: ItemKey) -> f64 {
    parse_replay_gain(tag.and_then(|tag| tag.get_string(key)))
}

replay_gain_track_gain_db: replay_gain(tag, ItemKey::ReplayGainTrackGain),
replay_gain_track_peak: replay_gain(tag, ItemKey::ReplayGainTrackPeak),
replay_gain_album_gain_db: replay_gain(tag, ItemKey::ReplayGainAlbumGain),
replay_gain_album_peak: replay_gain(tag, ItemKey::ReplayGainAlbumPeak),
```

在 Dart `LoftyMetadata` 相同位置加入：

```dart
@Double()
external double replayGainTrackGainDb;
@Double()
external double replayGainTrackPeak;
@Double()
external double replayGainAlbumGainDb;
@Double()
external double replayGainAlbumPeak;
```

在 `AudioMetadata` 增加四个可空字段、构造参数，并在 `readMetadata` 中使用：

```dart
double? _finiteOrNull(double value) => value.isFinite ? value : null;

replayGainTrackGainDb: _finiteOrNull(meta.replayGainTrackGainDb),
replayGainTrackPeak: _finiteOrNull(meta.replayGainTrackPeak),
replayGainAlbumGainDb: _finiteOrNull(meta.replayGainAlbumGainDb),
replayGainAlbumPeak: _finiteOrNull(meta.replayGainAlbumPeak),
```

- [ ] **Step 5: 构建并测试依赖**

```powershell
cargo fmt --manifest-path rust\lofty_ffi\Cargo.toml --check
cargo test --manifest-path rust\lofty_ffi\Cargo.toml
flutter test
```

预期：全部通过。在 fork 增加 `build-native.yml`，使用 `ubuntu-latest` 分别运行 `scripts/linux.sh` 与安装 `cargo-ndk` 后运行 `scripts/android.sh`，使用 `windows-latest` 的 Git Bash 运行 `scripts/windows.sh`，使用 `macos-latest` 安装 Rust Apple targets 后运行 `scripts/macos.sh` 与 `scripts/ios.sh`；每个 job 用 `actions/upload-artifact@v4` 上传对应平台目录。

```yaml
name: build-native
on:
  push:
    branches: [replaygain-metadata]
  workflow_dispatch:

jobs:
  linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: bash scripts/linux.sh
      - uses: actions/upload-artifact@v4
        with:
          name: linux-native
          path: linux/lib
  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo install cargo-ndk
      - run: bash scripts/android.sh
      - uses: actions/upload-artifact@v4
        with:
          name: android-native
          path: android/src/main/jniLibs
  windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: x86_64-pc-windows-gnu
      - run: bash scripts/windows.sh
      - uses: actions/upload-artifact@v4
        with:
          name: windows-native
          path: windows/lib
  apple:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
        with:
          targets: aarch64-apple-darwin,x86_64-apple-darwin,aarch64-apple-ios,aarch64-apple-ios-sim,x86_64-apple-ios
      - run: bash scripts/macos.sh
      - run: bash scripts/ios.sh
      - uses: actions/upload-artifact@v4
        with:
          name: macos-native
          path: macos/LoftyFFI.xcframework
      - uses: actions/upload-artifact@v4
        with:
          name: ios-native
          path: ios/LoftyFFI.xcframework
```

推送分支后等待并下载五个平台产物：

```powershell
git add .github/workflows/build-native.yml rust/lofty_ffi/src/lib.rs rust/lofty_ffi/tests/main.rs lib/src/loffy_ffi.dart pubspec.yaml
git commit -m "feat: expose ReplayGain metadata"
git push -u origin replaygain-metadata
$runId = gh run list --repo huya688zdx/audio_tags_lofty --workflow build-native.yml --branch replaygain-metadata --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch $runId --repo huya688zdx/audio_tags_lofty --exit-status
gh run download $runId --repo huya688zdx/audio_tags_lofty --name android-native --dir android/src/main/jniLibs
gh run download $runId --repo huya688zdx/audio_tags_lofty --name windows-native --dir windows/lib
gh run download $runId --repo huya688zdx/audio_tags_lofty --name linux-native --dir linux/lib
gh run download $runId --repo huya688zdx/audio_tags_lofty --name macos-native --dir macos/LoftyFFI.xcframework
gh run download $runId --repo huya688zdx/audio_tags_lofty --name ios-native --dir ios/LoftyFFI.xcframework
```

所有平台的 Rust 与 Dart 结构体字段顺序必须一致，五个 job 全部成功后再进入提交步骤。

- [ ] **Step 6: 提交并推送依赖**

```powershell
git add android/src/main/jniLibs ios/LoftyFFI.xcframework linux/lib macos/LoftyFFI.xcframework windows/lib
git commit -m "build: refresh ReplayGain native libraries"
git push origin replaygain-metadata
git rev-parse HEAD
```

将依赖版本改为 `0.0.7`，创建不可变标签并推送；随后删除 `F:\Symusic\audio_tags_lofty`：

```powershell
git tag v0.0.7-replaygain
git push origin replaygain-metadata v0.0.7-replaygain
```

### Task 2: 持久化 ReplayGain 元数据

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/base/my_audio_metadata.dart`
- Modify: `lib/base/data/database.dart`
- Modify: `lib/base/data/database.g.dart`
- Modify: `lib/base/extensions/metadata_extension.dart`
- Create: `test/metadata_database_test.dart`

- [ ] **Step 1: 先写数据库映射测试**

测试用 `NativeDatabase.memory()` 建立 `MetadataDB`，插入带四个数值的 `MyAudioMetadata`，再通过 `MetadataItemMapper.toMetadata()` 读回并断言四值相等；同时插入四值为空的记录并断言均为空。

- [ ] **Step 2: 运行测试确认失败**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\metadata_database_test.dart
```

预期：FAIL，`MyAudioMetadata` 尚无 ReplayGain getter，数据库列也不存在。

- [ ] **Step 3: 固定依赖并增加模型字段**

把 `pubspec.yaml` 改为执行 Task 1 得到的精确提交：

```yaml
audio_tags_lofty:
  git:
    url: https://github.com/huya688zdx/audio_tags_lofty.git
    ref: v0.0.7-replaygain
```

在 `MyAudioMetadata` 增加只读 getter，并在需要刷新远程标签时提供同名 setter，直接写入现有 `_audioMetadata`，不增加 bridge 类。

- [ ] **Step 4: 数据库迁移到版本 3**

在 `MetadataItems` 增加四个 `RealColumn nullable`，将 `schemaVersion` 改为 3，并在迁移中逐列添加：

```dart
if (from < 3) {
  await m.addColumn(metadataItems, metadataItems.replayGainTrackGainDb);
  await m.addColumn(metadataItems, metadataItems.replayGainTrackPeak);
  await m.addColumn(metadataItems, metadataItems.replayGainAlbumGainDb);
  await m.addColumn(metadataItems, metadataItems.replayGainAlbumPeak);
}
```

在两个 mapper 和 `Library.updateMetadata` 中完整映射四列，然后运行：

```powershell
F:\software\flutter_3.44.0\bin\dart.bat run build_runner build --delete-conflicting-outputs
F:\software\flutter_3.44.0\bin\flutter.bat test test\metadata_database_test.dart
```

预期：测试通过，`database.g.dart` 只出现四列及 schema 相关生成变化。

- [ ] **Step 5: 提交**

```powershell
git add pubspec.yaml pubspec.lock lib/base/my_audio_metadata.dart lib/base/data/database.dart lib/base/data/database.g.dart lib/base/extensions/metadata_extension.dart test/metadata_database_test.dart
git commit -m "feat(replaygain): persist audio gain metadata"
```

### Task 3: 实现同源回退与 Peak 防削波

**Files:**
- Create: `lib/base/services/replay_gain.dart`
- Create: `test/replay_gain_test.dart`
- Modify: `lib/base/services/usb_audio_preferences.dart`
- Modify: `test/usb_audio_preferences_test.dart`

- [ ] **Step 1: 写失败测试**

覆盖：关闭返回 0；track 优先 track；track 缺失回退 album；album 反向回退；Gain 与 Peak 不跨组；`peak <= 0`、NaN 和无穷值忽略；正增益被 `-20*log10(peak)` 限制；无 Peak 时最终线性输出不超过 1；偏好缺失默认 `off`。

- [ ] **Step 2: 运行测试确认失败**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\replay_gain_test.dart test\usb_audio_preferences_test.dart
```

预期：FAIL，因为 `ReplayGainMode`、`ReplayGainResult` 和选择函数尚不存在。

- [ ] **Step 3: 写最小纯逻辑实现**

`replay_gain.dart` 保持一个结果类型和一个选择函数：

```dart
import 'dart:math' as math;

import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';

class ReplayGainResult {
  final double gainDb;
  final double? peak;
  final ReplayGainMode? source;

  const ReplayGainResult(this.gainDb, this.peak, this.source);
}

ReplayGainResult replayGainFor(MyAudioMetadata song, ReplayGainMode mode) {
  if (mode == ReplayGainMode.off) return const ReplayGainResult(0, null, null);
  final order = mode == ReplayGainMode.track
      ? const [ReplayGainMode.track, ReplayGainMode.album]
      : const [ReplayGainMode.album, ReplayGainMode.track];
  for (final source in order) {
    final gain = source == ReplayGainMode.track
        ? song.replayGainTrackGainDb
        : song.replayGainAlbumGainDb;
    if (gain == null || !gain.isFinite) continue;
    final rawPeak = source == ReplayGainMode.track
        ? song.replayGainTrackPeak
        : song.replayGainAlbumPeak;
    final peak = rawPeak != null && rawPeak.isFinite && rawPeak > 0 ? rawPeak : null;
    final limit = peak == null ? gain : math.min(gain, -20 * math.log(peak) / math.ln10);
    return ReplayGainResult(limit, peak, source);
  }
  return const ReplayGainResult(0, null, null);
}

double dbToLinear(double db) => math.pow(10, db / 20).toDouble();

double replayGainWithinOutputHeadroom(double gainDb, double userLinearGain) {
  if (userLinearGain <= 0) return gainDb;
  final headroomDb = -20 * math.log(userLinearGain) / math.ln10;
  return math.min(gainDb, headroomDb);
}
```

在偏好中加入 `ReplayGainMode { track, album, off }`、默认 `off` 的 notifier，以及 `usbReplayGainMode` 的 `load/toMap` 映射。

- [ ] **Step 4: 运行测试并提交**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\replay_gain_test.dart test\usb_audio_preferences_test.dart
git add lib/base/services/replay_gain.dart lib/base/services/usb_audio_preferences.dart test/replay_gain_test.dart test/usb_audio_preferences_test.dart
git commit -m "feat(replaygain): select safe track and album gain"
```

预期：测试全部通过。

### Task 4: 读取 DSF 与云端 ReplayGain

**Files:**
- Modify: `lib/base/services/dsd_metadata.dart`
- Modify: `lib/base/services/metadata_service.dart`
- Modify: `lib/base/data/library.dart`
- Modify: `test/dsd_metadata_test.dart`

- [ ] **Step 1: 写 DSF TXXX 测试**

构造带 `REPLAYGAIN_TRACK_GAIN=-5.50 dB`、`REPLAYGAIN_TRACK_PEAK=0.91`、专辑 Gain/Peak 的 ID3v2.3 DSF 测试数据，断言 `readDsdMetadata` 返回四个数值。

- [ ] **Step 2: 运行测试确认失败**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\dsd_metadata_test.dart
```

预期：FAIL，当前 `_applyId3v2` 忽略 `TXXX`。

- [ ] **Step 3: 解析四个 TXXX 描述符**

在现有 ID3 循环中只识别四个大小写不敏感的描述符，并把数值写入 `AudioMetadata`。不改变普通标题、封面和其它帧行为。远程 DSF 若尾部标签尚未取得则保留空值。

- [ ] **Step 4: 补齐云端来源**

`MyAudioMetadata.fromOpenSonicMap` 优先读取 OpenSubsonic `replayGain` 对象的 `trackGain/trackPeak/albumGain/albumPeak`。缓存完成或流 URL 可进行范围读取时，用 `readMetadataAsync` 刷新仍为空的四字段并调用现有 `library.updateMetadata(song)`；解析失败只写开发者日志，不阻塞起播。

- [ ] **Step 5: 运行测试并提交**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\dsd_metadata_test.dart test\metadata_database_test.dart
git add lib/base/services/dsd_metadata.dart lib/base/services/metadata_service.dart lib/base/data/library.dart lib/base/my_audio_metadata.dart test/dsd_metadata_test.dart test/metadata_database_test.dart
git commit -m "feat(replaygain): read DSD and remote gain tags"
```

### Task 5: 接入设置页与本地化

**Files:**
- Modify: `lib/layer/audio_output_settings_layer.dart`
- Modify: `lib/layer/layers_manager.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/generated/app_localizations*.dart`

- [ ] **Step 1: 增加本地化键**

增加 `replayGain`、`replayGainTrack`、`replayGainAlbum`、`replayGainOff` 和说明文本，中英文含义一致，不硬编码用户可见文字。

- [ ] **Step 2: 接入现有详情导航**

为 `AudioOutputSettingsPageKind` 增加 `replayGain`；overview 的音量区域加入 `_navTile`；详情页使用现有 `_radioTile` 展示 track、album、off。`layers_manager` 增加 `usb_replay_gain`，使用 `audioOutputVisibleNotifier`，确保横屏父页与详情页互斥显示且可返回。

- [ ] **Step 3: 生成并验证**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.0\bin\flutter.bat analyze
```

预期：生成成功，`No issues found`。

- [ ] **Step 4: 提交**

```powershell
git add lib/layer/audio_output_settings_layer.dart lib/layer/layers_manager.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/generated
git commit -m "feat(replaygain): add playback gain setting"
```

### Task 6: 接入普通输出与 USB 请求

**Files:**
- Modify: `lib/base/audio_handler.dart`
- Modify: `lib/base/services/usb_audio_service.dart`
- Modify: `test/usb_audio_service_test.dart`

- [ ] **Step 1: 先扩展 USB 映射测试**

在现有 `UsbExclusivePlaybackRequest.toMap` 测试中传入 `replayGainDb: -5.5`，断言 map 包含 `replayGainMilliDb: -5500`；关闭或无标签时断言为 0。为 `setExclusiveVolume` 同样断言当前歌曲的 milli-dB 被传递。

- [ ] **Step 2: 运行测试确认失败**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\usb_audio_service_test.dart
```

预期：FAIL，请求类型尚无 ReplayGain 字段。

- [ ] **Step 3: 扩展 USB 请求而不预先合并来源**

在请求、`setExclusiveVolume` 和 MethodChannel map 增加 `replayGainMilliDb`。继续单独发送用户 `volumeGainQ16` 与 `dsdGainCompensationDb`，让原生层能在 DAC 主动改变音量时反推基础用户音量。

- [ ] **Step 4: 普通输出应用独立 dB 增益**

在 `MyAudioHandler` 保存当前 `ReplayGainResult`。每次 `load()` 确定歌曲后重新计算；共享输出在 `_player.open` 前后设置 libmpv `volume-gain` 为 `gainDb.toStringAsFixed(3)`；关闭、缺失标签和切歌都显式写 `0`。偏好或用户音量变化时重新按输出余量限制当前增益，并同时刷新普通输出或 USB 目标。

- [ ] **Step 5: 运行相关测试并提交**

```powershell
F:\software\flutter_3.44.0\bin\flutter.bat test test\replay_gain_test.dart test\usb_audio_preferences_test.dart test\usb_audio_service_test.dart test\dsd_metadata_test.dart test\metadata_database_test.dart
F:\software\flutter_3.44.0\bin\flutter.bat analyze
git add lib/base/audio_handler.dart lib/base/services/usb_audio_service.dart test/usb_audio_service_test.dart
git commit -m "feat(replaygain): apply gain to every playback path"
```

预期：相关测试通过，`No issues found`。
