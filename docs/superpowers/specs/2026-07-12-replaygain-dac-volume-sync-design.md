# ReplayGain 与 DAC 双向音量同步设计

## 目标

在不改变现有播放页视觉风格和 USB 独占数据格式选择的前提下，完成以下能力：

- 提供“按音轨 / 按专辑 / 关闭”三种 ReplayGain 模式；
- 让本地、WebDAV、Navidrome、Emby、普通系统输出和 USB 独占输出使用同一套 ReplayGain 决策；
- 让支持读取或主动上报音量的 DAC 与应用音量双向同步；
- 让 Android 物理音量键在锁屏和后台播放时仍能调整当前有效音量；
- 将 Macaron 的具体命令从独占引擎通用逻辑中隔离，使后续厂商可以按日志和适配手册快速接入。

不在本次范围内：强制停止应用后的按键接管、没有任何硬件增益能力时修改原生 DSD/DoP 位流、与 USB 无关的页面视觉或播放架构重构。

## 产品语义

### ReplayGain 模式

新增 `ReplayGainMode`：

- `track`：优先音轨 Gain/Peak，缺失时回退到专辑 Gain/Peak；
- `album`：优先专辑 Gain/Peak，缺失时回退到音轨 Gain/Peak；
- `off`：不应用 ReplayGain。

默认值为 `off`，避免升级后自动改变用户原有响度。设置入口沿用 USB 输出设置页面现有的多级详情导航范式，文案同时进入中英文 ARB。

没有可用 Gain 标签时按 `0 dB` 处理。Gain 与 Peak 必须成对遵循同一回退来源，不能使用音轨 Gain 搭配专辑 Peak。

### 防削波

选中的标签增益记为 `tagGainDb`，标签峰值记为 `peak`：

```text
peakLimitDb = -20 * log10(peak)
effectiveReplayGainDb = min(tagGainDb, peakLimitDb)  // peak 有效时
effectiveReplayGainDb = tagGainDb                    // peak 缺失时
```

最终目标仍需限制在当前输出端的有效增益范围内。没有 Peak 时不额外设置预放大，数字输出必须限制到 0 dBFS；硬件输出不得写出设备声明范围。

ReplayGain 只改变当前歌曲的有效增益，不改变用户音量滑块和持久化的基础音量。切歌时重新计算并平滑交接。

## 元数据链路

当前 `audio_tags_lofty` 已负责本地和远程音频标签读取，但没有暴露 Lofty 已支持的 ReplayGain 项。扩展该依赖的 `AudioMetadata`，增加四个可空字段：

- `replayGainTrackGainDb`
- `replayGainTrackPeak`
- `replayGainAlbumGainDb`
- `replayGainAlbumPeak`

Rust FFI 负责从 Lofty `ItemKey` 读取不同容器的标准映射并解析数值。应用层不新增 MP3、Vorbis Comment、APEv2 或 ID3 的重复解析器。

四个字段进入 `MyAudioMetadata` 和 Drift 元数据表，数据库版本递增并执行可空列迁移。云端源如果服务端列表接口没有返回 ReplayGain，则沿用现有文件标签读取或缓存完成后的元数据刷新流程；读不到标签时保持空值，不阻塞播放。

依赖改动应形成 `audio_tags_lofty` 的独立、可复用提交，并在主项目固定到包含该变更的版本或提交，避免依赖未发布行为。

## 统一增益模型

播放层持有以下互相独立的量：

- `userVolume`：用户看到并保存的 0–1 音量；
- `replayGainDb`：当前歌曲计算后的 ReplayGain；
- `dsdCompensationDb`：现有 DSD 增益补偿；
- `outputCapabilities`：当前输出端能否硬件调音量、能否处理 DSD 增益、范围和步进。

共享的增益计算函数只负责选择标签、限制 Peak 和合成目标，不直接访问播放器或 USB。输出路径再将结果映射到自己的控制方式。

### 普通系统输出

用户音量继续沿用现有感知曲线。ReplayGain 作为独立 dB 增益交给 media_kit/libmpv，切歌或修改模式时更新。关闭时明确复位为 `0 dB`，防止上一首歌曲的值残留。

### USB 独占 PCM

优先把合成后的目标转换为 DAC 硬件音量：

```text
targetLinear = perceptual(userVolume) * dbToLinear(replayGainDb)
```

硬件控制可用时，将 `targetLinear` 映射到设备原始级数并限制在设备范围内。硬件范围不足或当前设备没有硬件音量时，依照现有“自动 / DAC 硬件 / 数字 / 原始”模式决定是否使用原生 PCM 数字增益；不得把数字回退伪装成硬件音量。

### USB 独占 DSD 与 DoP

不得为 ReplayGain 直接修改 DSD 或 DoP 数据。设备提供标准硬件音量或已适配的 DSD 增益寄存器时，在 DAC 端合成：

```text
deviceTarget = userVolume + replayGainDb + dsdCompensationDb
```

三个来源仍分别保留，便于切歌、切模式和硬件按键变化后重新计算。设备没有可用硬件能力时保持原始 DSD/DoP，并在状态和诊断中说明 ReplayGain 未应用，不静默转换为 PCM。

## DAC 协议适配

### 最小协议边界

`UsbExclusiveAudioEngine` 继续负责 USB 会话、播放线程、缓冲和状态；具体厂商音量协议放入小型协议实现，不建立额外业务框架。协议实现只提供：

- 能力：原始范围、步进、是否可读、是否有主动事件、是否有独立 DSD 增益；
- 将应用目标转换为设备原始值；
- 写入目标音量；
- 读取当前音量；
- 解析命令响应和设备主动上报；
- 将设备原始值还原为规范化音量。

设备 quirk 只保存协议标识和已验证参数。匹配顺序为标准 UAC Feature Unit、已知厂商协议、数字回退；不得仅凭同一厂商 VID 推断所有产品使用相同命令。

Macaron/DC03 Pro 作为第一个厂商协议实现，现有寄存器和 HID 命令从引擎通用分支迁入该实现，行为保持不变。

### 单一读取者

带主动事件的 HID 设备由一个持续读取循环独占 IN 端点。读取循环把数据分为：

- 当前命令的响应；
- DAC 按钮或旋钮产生的主动音量事件；
- 无法识别的数据。

同步命令不得再与事件监听器竞争同一 IN 端点。命令通过序号或协议可识别字段等待自己的响应，超时后走现有安全回退。

### 双向同步与防回环

应用写入 DAC 后记录最后一次原始目标和来源。读取到相同值的确认只完成校验，不再次写回；只有不同的设备主动值才发布到 Dart。

设备主动值代表包含 ReplayGain 和 DSD 补偿后的实际目标。应用按当前歌曲状态反推基础用户音量：

```text
userTarget = deviceActual - replayGainDb - dsdCompensationDb
```

反推结果按设备步进和应用 0–1 范围限制，随后更新音量通知器、浮层和持久化状态。由于设备级数可能有量化误差，采用原始级数等价判断和短时间去抖，避免来回跳一级。

设备拔出、读取失败或协议不支持事件时，停止监听并保留最后一次确认音量；重新连接后先读取设备真实值，再按“音量平滑交接”策略决定从设备值接管或写入应用值。

## Android 后台物理按键

现有 `MainActivity.dispatchKeyEvent` 只在 Activity 存活且位于前台时工作。改为使用 `audio_service` 已提供的 Android 远程音量媒体会话：

- USB 独占且音量控制实际生效时，发布 `RemoteAndroidPlaybackInfo`，最大值 100，当前值为应用基础音量百分比；
- 覆盖远程相对调整和绝对设置回调，统一调用 `MyAudioHandler` 的音量入口；
- 非 USB 独占时恢复 `LocalAndroidPlaybackInfo`，让系统音量保持原行为；
- 删除或停用 Activity 级重复拦截，避免前台一次按键触发两次。

播放服务存活时，锁屏、熄屏和应用退到后台仍由 Android MediaSession 路由按键。用户在系统设置中强制停止应用后，服务无法继续接收按键，这是明确的系统边界。

## 界面与状态表达

回放增益详情页沿用现有设置层样式，展示三项单选，不新增预放大设置。所有用户可见文案进入 `app_zh.arb` 和 `app_en.arb`。

信号输出区域按真实情况组合展示：

- `DAC 硬件音量`：当前目标完全由 DAC 控制；
- `数字音量`：PCM 数据经过数字缩放；
- `原始输出`：没有任何音量处理；
- ReplayGain 生效时追加当前有效值；
- DSD/DoP 因设备能力未应用 ReplayGain 时显示明确说明。

不把设备专有寄存器、芯片型号或 Macaron 文案放进普通用户界面。详细原始值只进入开发者诊断。

## 诊断与适配手册

更新 `docs/dac-adaptation-guide.md`，以通用流程为主体：

1. 收集 VID/PID、USB 描述符、接口和端点；
2. 判断标准 UAC、HID、Bulk 或其它厂商协议；
3. 捕获写入、读取、设备按钮主动事件；
4. 确认原始范围、步进、左右声道和静音值；
5. 实现协议并配置精确 quirk；
6. 运行协议单元测试、设备回读和断连测试；
7. 将已验证日志附到适配记录。

诊断报告增加协议标识、能力、原始值、规范化值、最后命令、回读结果、主动事件支持、ReplayGain/DSD 补偿以及最终硬件/数字选择。报告正文和原生日志使用英文。

## 错误处理

- 非法 ReplayGain 字符串视为标签缺失，并记录一次开发者日志；
- NaN、无穷值、非正 Peak 不参与防削波计算；
- 切歌并发通过歌曲/加载代次丢弃过期的增益结果；
- DAC 写入后回读不一致时，以设备读值为准并记录校验失败；
- 主动事件读取线程异常时可重建一次，连续失败则降级为只写模式；
- 任何硬件降级必须同步更新状态，不能继续显示 `hardware=true`；
- 设置变化立即作用于当前歌曲，并在下一首沿用。

## 测试与验证

纯逻辑测试覆盖：

- 音轨/专辑双向回退；
- Gain 与 Peak 同源选择；
- Peak 防削波和非法标签；
- 用户音量、ReplayGain、DSD 补偿的合成与反推；
- 设备步进量化和回环抑制；
- 协议响应与主动事件分流；
- 标准 UAC、厂商协议和数字回退选择；
- ReplayGain 偏好持久化及数据库迁移。

设备验证覆盖：

- 应用滑块控制 DAC，并能回读一致；
- DAC 外置按键同步应用滑块和音量浮层；
- 前台、锁屏、熄屏、后台的手机物理键；
- PCM、原生 DSD、DoP 下的实际控制方式和状态文案；
- 切歌 ReplayGain 平滑变化、断连回退和重新连接；
- 没有 ReplayGain 标签、只有一类标签、可能削波的正增益歌曲。

完成后使用指定 Flutter 3.44 执行本地化生成、相关测试、完整 `analyze`，只构建 Android `arm64-v8a` profile 包进行真机验证。
