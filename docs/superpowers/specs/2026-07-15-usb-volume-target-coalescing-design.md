# USB 硬件音量统一绝对目标协调设计

## 背景

当前 USB 硬件音量已经在原生层使用单线程事务和单个 pending 请求，但不同输入来源仍有不同的排队语义：

- 手机物理按键在 Dart 层保留一个待处理方向，再逐步下发。
- 设置页 Slider 直接连续下发绝对音量目标。
- ReplayGain 安全渐升每 100ms 计算并下发一个新的绝对目标。

真机日志证明，iBasso Macaron 在连续 HID 音量事务下会间歇失去响应。一次完整失败链如下：

1. `21:40:51.194` 开始事务，成功写入并回读寄存器 `98`。
2. `21:40:51.407` 开始下一事务，成功写入并回读寄存器 `96`。
3. `21:40:51.796` 开始第三笔密集事务。
4. `21:40:52.054` reader 报告 pending response 未返回。
5. `21:40:52.055` 写 ACK 超时，进入 command 65 回读确认。
6. `21:40:52.757` command 65 仍超时，PCM 硬件音量被冻结。

因此，界面快速显示“音量同步失败”不是状态误报，而是密集事务在约一秒内触发了现有安全冻结逻辑。冻结期间没有写入寄存器 0，也没有启用数字音量回退。

## 目标

- 手机按键、Slider 和 ReplayGain 渐升统一使用“最新绝对目标”语义。
- 所有来源共用原生单线程协调器，不建立点击计数、方向队列或延迟任务队列。
- 提高请求可以合并为最新目标，避免逐个执行 Slider 中间值。
- 降低请求一旦进入 pending，后续提高请求不得覆盖；更低请求可以继续覆盖。
- iBasso 硬件事务之间保留 150ms 稳定间隔，让 reader 和设备完成响应收尾。
- 保持现有 ACK 回读、PCM 冻结、DSD 暂停和禁止数字回退的安全逻辑。

## 非目标

- 不修改 USB 以外的播放器页面、歌词页、背景视觉或交互。
- 不改变 Slider 的视觉、范围、曲线或触摸手感。
- 不改变手机按键单次 2% 步进。
- 不改变 ReplayGain 的 1dB 安全增幅限制。
- 不通过增加 HID 超时来掩盖密集事务问题。
- 不自动播放，不从 ADB 发送音量增加或媒体按键命令。

## 方案比较

### 方案一：原生统一协调和稳定间隔（采用）

所有绝对目标继续汇合到 `UsbExclusiveAudioEngine.setVolume()`。原生协调器负责单 pending 合并、降低锁存和 iBasso 事务间隔；Dart 只负责把手机按键转换成绝对目标。

优点是三个输入来源最终遵守同一规则，安全状态仍由掌握硬件回读结果的原生层决定。改动集中在已有协调器和按键处理逻辑，不增加 manager 或新架构层。

### 方案二：仅在 Dart 层防抖（不采用）

在 Flutter 层统一 Slider、按键和 ReplayGain 定时器，再延迟调用平台通道。

该方案无法可靠判断硬件事务何时回读确认，也容易与会话切换、DSD 状态和原生冻结状态产生竞态，因此不能承担降低锁存的最终安全责任。

### 方案三：只延长 HID 超时和重试（不采用）

保留现有输入频率，仅增加 ACK、reader 和 command 65 的等待时间。

该方案会让失败更晚暴露，却不会减少设备负载；密集 Slider 和 ReplayGain 仍会产生连续中间写入，不解决根因。

## 架构与数据流

### Dart 输入层

手机按键不再维护 `_pendingPhoneVolumeDirection` 和 `_phoneVolumeKeyWriteInProgress`。每个有效按键事件继续使用 `adjustedRemoteVolume()` 计算 2% 步进，并立即更新应用内绝对音量目标，再通过现有 `_setUserVolumeImmediately()` 路径下发。

该调用不等待上一笔手机按键写入完成，也不保存按键方向。快速按键、Slider 和 ReplayGain 允许产生多个请求，但它们都只表达当前希望达到的绝对状态，最终由原生协调器合并。

音量浮层仍随每个有效手机按键事件显示，用户界面不等待 DAC 回读后才响应。

### 原生请求层

`UsbVolumeRequest` 继续携带用户增益、ReplayGain、模式、DSD 补偿、平滑切换和会话代次。增加纯逻辑，用请求的总有效输出增益比较 running、pending 和 incoming。PCM 比较用户增益与 ReplayGain 的组合结果；DSD 在该结果上加入当前请求的 DSD 补偿。比较函数显式接收当前会话是否为 DSD，不从全局状态读取：

- 没有 pending 时，incoming 成为唯一 pending。
- pending 低于当前 running，说明已经锁存降低目标：
  - incoming 更低时，以 incoming 覆盖 pending。
  - incoming 相同或更高时，保留 pending。
- pending 不低于 running 时，没有待执行降低：保留最新 incoming。
- 模式或会话代次不同的请求不做跨模式增益比较，沿用最新请求和现有会话失效检查。

降低目标被取出成为 running 后，后续提高可以成为下一笔 pending，但只能等降低事务完成并回读确认后执行。如果降低事务失败并进入 frozen，后续请求仍会经过现有冻结入口，只尝试恢复回读，不写入新的提高目标。

### iBasso 稳定间隔

第一笔会话请求不增加等待。每笔 iBasso 硬件音量事务完成后，协调器保持 running 状态 150ms，再读取合并后的 pending：

- 间隔期间到达的请求只更新单个 pending。
- 150ms 后最多执行一个合并结果。
- 没有 pending 时结束 drain，并清除 running 状态。
- 非 iBasso 数字音量和其它协议不增加该稳定间隔。
- 会话代次变化时继续丢弃旧 pending；稳定等待结束后必须再次检查代次。

稳定间隔运行在已有单线程 executor 中，不占用主线程，也不创建额外定时器或工作队列。

## 安全与错误处理

- 降低锁存优先于提高合并，保证同一 pending 窗口内的提高不能吞掉降低。
- 所有提高仍经过现有 `safeOutputGainTransition()`，保持 1dB 安全渐升限制。
- iBasso 写 ACK 超时仍先执行最多三次 command 65 回读。
- 回读命中新目标才变更硬件权威；命中旧目标则保留旧权威。
- PCM 持续失败继续冻结硬件控制，不启用数字音量，不写单位增益或寄存器 0。
- DSD 持续失败继续暂停，恢复可信回读后不自动播放。
- 日志继续使用英文，只记录事务开始/完成、合并、回读和冻结，不记录每个 PCM 样本。

## 测试设计

### Kotlin 纯逻辑测试

- 连续提高请求保留最新绝对目标。
- pending 为降低目标时，后续提高不能覆盖。
- 更低目标可以覆盖已锁存的降低目标。
- 降低成为 running 后，提高只能成为下一笔 pending。
- 模式或会话代次变化沿用最新请求，不跨状态比较。
- iBasso 稳定间隔计算：第一笔为 0ms，间隔不足时返回剩余时间，达到 150ms 后为 0ms。

### Dart 测试

- 保留单次手机按键 2% 步进和边界限制。
- 删除方向 pending 规则测试。
- 增加测试确认手机按键转换为绝对目标，不累计方向或点击计数。

### 自动验证

- `android\gradlew.bat app:testDebugUnitTest`
- `F:\software\flutter_3.44.5\bin\flutter.bat test`
- `F:\software\flutter_3.44.5\bin\flutter.bat analyze`
- `F:\software\flutter_3.44.5\bin\flutter.bat build apk --profile --target-platform android-arm64`

### 真机验收

在用户确认安全音量后，由用户手动完成：

1. 连续操作手机音量键。
2. 在安全范围快速往返拖动 Slider。
3. 切换带 ReplayGain 的 PCM 歌曲并等待渐升结束。

日志应满足：

- 同时只有一个硬件音量事务。
- pending 始终只有一个绝对目标。
- 降低目标不会被同窗口的提高覆盖。
- iBasso 事务之间至少保留设计的稳定间隔。
- 不再因上述密集操作出现连续 `pending response`、ACK 和 command 65 超时。
- 不出现 `register=0`、`digital=true` 或自动播放。

## 提交边界

设计实现仅允许修改 USB 音量协调相关文件、对应测试和本设计后续实施计划。必须继续保留工作区中已有的用户修改，不得暂存：

- `UsbExclusiveAudioEngine.kt` 中 `initialState` 的 `playbackId` 排序。
- `audio_handler.dart` 和 `audio_output_panel.dart` 的用户格式化 hunk。
- USB 云端恢复设计文档中的 Flutter 版本调整。
- Linux、macOS 和 Windows generated plugin 文件的行尾状态。
