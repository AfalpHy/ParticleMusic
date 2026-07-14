# USB 音量安全、硬件同步与 ReplayGain 实施计划

> **执行要求：** 按任务顺序测试驱动实施；每个任务只暂存本任务改动，保留工作区原有未提交修改。每个任务验证、提交并推送后再进入下一项。

**目标：** 阻止 DSD 在未确认硬件音量时满幅播放，统一限制音量上升，修复 iBasso 双向音量同步和重复音量条，并让 Navidrome ReplayGain 在在线与缓存路径稳定生效。

**实现原则：** 沿用现有 `MyAudioHandler`、`UsbExclusiveAudioEngine`、`UsbVolumeProtocol`、DAC quirk 和 metadata 数据库，不引入新的 manager/bridge。Dart 层负责用户目标、渐升与媒体状态；Kotlin 层作为 DSD 最终安全门；ReplayGain 以 OpenSubsonic API 为主、缓存文件标签补缺。位深修复只更正状态判定和显示，不在本轮替换解码器。

**技术栈：** Flutter/Dart、audio_service、media_kit、Android Kotlin、USB Host API、Drift、Dio、audio_tags_lofty、JUnit、flutter_test。

---

## 任务 1：DSD 硬件音量安全门

**文件：**

- 修改：`android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- 修改：`android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- 修改：`android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`

### 1.1 先写失败测试

在 `UsbVolumeProtocolTest.kt` 增加纯逻辑测试，覆盖：

- PCM 硬件音量失败时允许数字回退。
- DSD/DoP 硬件音量已确认时允许启动。
- DSD/DoP 硬件音量未激活、回读不可信或 write-only 时拒绝启动。
- raw 模式不被错误当作安全音量路径。

### 1.2 运行测试并确认失败

```powershell
cd android
./gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest"
```

预期：新安全判定尚不存在或返回错误，测试失败。

### 1.3 最小实现

- 在 `UsbVolumeProtocol.kt` 增加纯函数，只表达“当前格式能否安全开始传输”。
- `applyVolumeControl()` 完成后由引擎检查该结果。
- 对 DSD/DoP，未确认硬件音量时在提交 URB 前终止准备并返回明确英文状态。
- 保持 PCM 数字音量回退行为不变。
- 不修改 DSD/DoP 音频数据。

### 1.4 验证、提交、推送

```powershell
cd android
./gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest"
cd ..
git diff --check
git diff --stat
git diff
git commit -m "fix(usb): 阻止未确认音量的 DSD 播放"
git push fork usb-exclusive-volume-overlay-performance
```

---

## 任务 2：统一音量上升保护并消除重复音量条

**文件：**

- 修改：`lib/base/audio_handler.dart`
- 修改：`lib/base/widgets/usb_exclusive_volume_overlay.dart`
- 修改：`test/android_remote_volume_test.dart`
- 新增：`test/usb_volume_safety_test.dart`

### 2.1 先写失败测试

覆盖纯逻辑：

- 降低目标立即返回目标值。
- 上升一步最多增加 `0.02`。
- 连续渐升每个 tick 最多 `0.02`。
- 新降低请求覆盖旧上升目标。
- Android 绝对音量的大幅上调不能绕过限制。
- DAC 已确认音量成为下一次手机物理键的计算基准。
- Android 远程音量来源不触发自绘提示，DAC 来源仍触发。

### 2.2 运行测试并确认失败

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart test/usb_volume_safety_test.dart
```

### 2.3 最小实现

- 在 `audio_handler.dart` 顶层现有远程音量辅助函数附近加入最小纯函数，不新建 manager。
- `_setUserVolume` 接收是否显示自绘提示的布尔参数。
- Android 远程音量请求保存最终目标；降低立即执行，上升通过单一 `Timer` 每 100 ms 推进最多 `0.02`。
- 切歌、暂停、停止和新加载代次取消旧 Timer。
- DAC 回报更新 `volumeNotifier` 与 playback info，不回写同值；异常向上超过 `0.02` 时只回写安全目标。
- 手机物理键不增加 `usbVolumeOverlayNotifier`；DAC 主动通知保留自绘提示。
- 保持现有 UI 样式不变。

### 2.4 验证、提交、推送

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/android_remote_volume_test.dart test/usb_volume_safety_test.dart test/replay_gain_test.dart
git diff --check
git diff --stat
git diff
git commit -m "fix(usb): 限制音量上升并去除重复提示"
git push fork usb-exclusive-volume-overlay-performance
```

---

## 任务 3：iBasso 32 字节 HID 音量通知

**文件：**

- 修改：`android/app/src/main/kotlin/com/afalphy/sylvakru/UsbVolumeProtocol.kt`
- 修改：`android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- 修改：`android/app/src/test/kotlin/com/afalphy/sylvakru/UsbVolumeProtocolTest.kt`
- 修改：`docs/usb-dac-vendor-adaptation.md`（若仓库现有文档名称不同，则更新现有对应文档，不新建重复手册）

### 3.1 获取可信样本

- 使用只读 ADB 日志记录旋钮向上一步、向下一步、PCM/DSD 各一次。
- 对照官方 `com.ibasso.volume` 行为和现有静态包，确认 32 字节 report 的命令/域和值偏移。
- 若设备连接不可用，不猜测偏移；先只完成可由已有样本证明的解析测试，并把真机验证列为未完成。

### 3.2 先写失败测试

覆盖：

- 已验证的 16 字节事件仍可解析。
- 32 字节 PCM/DSD 主动通知解析为正确 raw 值。
- 32 字节命令响应进入 pending response，不误发旋钮事件。
- 无效长度、无效域、越界值保持 Unknown。
- 最近写入的同值只作为确认，不产生重复 UI 事件。

### 3.3 最小实现

- 扩展 `routeIbassoVolumePacket()`，按已验证的 report 形态路由。
- 主动通知与响应使用不同判断，不依赖单一固定偏移。
- 延续当前串行 pending command 和 reader generation 机制。
- 更新厂商适配文档，说明日志采集、report 识别、读写校验和安全回退要求。

### 3.4 验证、提交、推送

```powershell
cd android
./gradlew.bat app:testDebugUnitTest --tests "com.afalphy.sylvakru.UsbVolumeProtocolTest"
cd ..
git diff --check
git diff --stat
git diff
git commit -m "fix(usb): 识别 iBasso 硬件音量通知"
git push fork usb-exclusive-volume-overlay-performance
```

---

## 任务 4：Navidrome ReplayGain API 刷新与缓存兜底

**文件：**

- 修改：`lib/base/services/open_sonic_client.dart`
- 修改：`lib/base/services/navidrome_client.dart`（仅在 Navidrome 特有行为需要覆盖时）
- 修改：`lib/base/my_audio_metadata.dart`
- 修改：`lib/base/data/library.dart`
- 修改：`lib/base/audio_handler.dart`
- 修改：`lib/base/services/replay_gain.dart`
- 修改：`test/open_subsonic_replay_gain_test.dart`
- 修改：`test/cloud_download_client_test.dart`
- 修改：`test/replay_gain_test.dart`

### 4.1 先写失败测试

覆盖：

- `getSong` 返回的 `replayGain` 能补齐当前在线歌曲。
- API 已有字段不被文件标签覆盖。
- `cacheExist=true` 且数据库字段为空时仍扫描已有缓存。
- 补齐结果写入数据库并发出当前歌曲元数据事件。
- 非当前歌曲补齐不改变当前播放增益。
- 播放中新增衰减立即生效，新增正向有效增益走安全渐升。
- API 失败或无标签时保持 0 dB 且不阻止播放。

### 4.2 运行测试并确认失败

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/open_subsonic_replay_gain_test.dart test/cloud_download_client_test.dart test/replay_gain_test.dart
```

### 4.3 最小实现

- 在 `OpenSubsonicClient` 增加 `getSong(id)`，复用现有鉴权和 `safeRequest`。
- 为缺少首选 ReplayGain 的当前/下一首执行一次详细元数据补充，使用已有加载代次阻止旧结果污染当前歌曲。
- `tryAddCache()` 遇到已存在完整缓存时仍允许执行一次 ReplayGain 补读，而不是直接返回。
- 只补缺失的有效字段并持久化。
- 增加不含认证信息的英文诊断日志，记录 API、cache、selected mode、最终 dB。
- 所有增益上调交给任务 2 的安全渐升。

### 4.4 验证、提交、推送

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/open_subsonic_replay_gain_test.dart test/cloud_download_client_test.dart test/replay_gain_test.dart test/metadata_database_test.dart
git diff --check
git diff --stat
git diff
git commit -m "fix(usb): 补齐 Navidrome 回放增益元数据"
git push fork usb-exclusive-volume-overlay-performance
```

---

## 任务 5：切歌有效增益交接

**文件：**

- 修改：`lib/base/audio_handler.dart`
- 修改：`lib/base/services/replay_gain.dart`
- 修改：`test/replay_gain_test.dart`
- 修改：`test/usb_volume_safety_test.dart`

### 5.1 先写失败测试

覆盖：

- 新歌曲目标更安静时立即使用新值。
- 新歌曲目标更响时从上一首确认值开始渐升。
- PCM 到 DSD、DSD 到 PCM 使用相同有效增益规则。
- 旧歌曲的延迟 ReplayGain 事件不能修改新歌曲。

### 5.2 最小实现

- 在现有 `load()` 代次内保存上一首最后有效增益。
- 计算新歌曲用户音量、ReplayGain 和 DSD 补偿后的目标。
- 降低立即下发；增加复用任务 2 的 Timer。
- USB 会话建立时使用安全起始值，硬件确认后才允许恢复。

### 5.3 验证、提交、推送

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat test test/replay_gain_test.dart test/usb_volume_safety_test.dart test/usb_audio_service_test.dart
git diff --check
git diff --stat
git diff
git commit -m "fix(usb): 平滑交接切歌有效增益"
git push fork usb-exclusive-volume-overlay-performance
```

---

## 任务 6：位深诚实状态与展示

**文件：**

- 修改：`android/app/src/main/kotlin/com/afalphy/sylvakru/UsbExclusiveAudioEngine.kt`
- 修改：`lib/base/services/usb_audio_service.dart`
- 修改：`lib/base/widgets/audio_output_panel.dart`
- 修改：`lib/l10n/app_zh.arb`
- 修改：`lib/l10n/app_en.arb`
- 修改：`test/usb_audio_service_test.dart`
- 修改：相关 Kotlin 状态测试（优先放入现有 `UsbDsdTest.kt` 或 `UsbVolumeProtocolTest.kt`）

### 6.1 先写失败测试

覆盖：

- 源 24-bit、解码 16-bit、USB 24-bit 槽位时 bit-perfect 为 false。
- 三个位深一致且没有数字处理时才允许 bit-perfect。
- DSD 不被 PCM 位深规则误判。
- Dart 状态模型能独立解析源位深、解码位深和 USB 槽位。

### 6.2 最小实现

- 原生状态增加明确的源位深、解码有效位深和 USB 槽位字段。
- 状态页沿用现有视觉，只调整文字和值，不改布局风格。
- 新增用户文字时同步中英文 ARB，并使用项目本地化系统。
- 不引入软件解码器，不把 16→24 填充显示为 24-bit bit-perfect。

### 6.3 验证、提交、推送

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.5\bin\flutter.bat test test/usb_audio_service_test.dart
cd android
./gradlew.bat app:testDebugUnitTest
cd ..
git diff --check
git diff --stat
git diff
git commit -m "fix(usb): 如实显示解码与 USB 位深"
git push fork usb-exclusive-volume-overlay-performance
```

---

## 任务 7：整体回归、构建与真机验证

### 7.1 静态与测试验证

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat gen-l10n
F:\software\flutter_3.44.5\bin\flutter.bat test
F:\software\flutter_3.44.5\bin\flutter.bat analyze
cd android
./gradlew.bat app:testDebugUnitTest
cd ..
```

### 7.2 arm64 构建

```powershell
F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64
```

### 7.3 真机场景

- PCM 播放时手机物理键只出现系统音量条。
- DAC 旋钮变化更新应用音量，下一次手机按键从新值继续。
- 息屏和后台时手机物理键仍控制 DAC。
- PCM 切 PCM、PCM 切 DoP/Native DSD、DSD 切 PCM 不出现突然放大。
- 拔插 DAC、硬件回读超时和 reader 重启时 DSD 保持静音并拒绝不安全启动。
- Navidrome 在线曲目无需转成本地歌曲即可显示并应用 ReplayGain。
- 24-bit 文件若实际解码为 16-bit，状态页明确显示该事实。

若 ADB 或实机不可用，必须明确列出未完成场景，不得用单元测试替代真机结论。

### 7.4 最终检查

```powershell
git status
git log --oneline -10
git diff --check
```

确认所有任务提交均已推送到 `fork/usb-exclusive-volume-overlay-performance`，工作区剩余修改仅为任务开始前已经存在的用户修改。
