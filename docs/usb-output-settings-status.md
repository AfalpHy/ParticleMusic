# USB 输出设置接入状态

本文档记录 `USB 输出设置` 页面各项与当前真实播放链路的对应关系。状态以代码、自动测试和已有设备证据为准；尚未完成本轮真机验收的行为会明确标注，不因代码已接入就写成“真机已验证”。

## 已接入运行链路

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| Android USB 插入声明 | 已接入 | `AndroidManifest.xml` 已声明 `android.hardware.usb.action.USB_DEVICE_ATTACHED`，`usb_audio_device_filter.xml` 已包含 USB Audio Class 和 Macaron VID/PID。`dumpsys usb` 能看到 `com.afalphy.sylvakru.debug` 注册到 `device_attached_activities`。 |
| USB 设备识别 | 已接入 | 通过 Android 侧 USB/AudioDevice 状态回传，设置页能显示 DAC 名称、USB ID、系统输出设备、采样率和编码等信息。 |
| USB 权限与独占诊断 | 已接入 | `probeExclusiveAccess()` 会检查 USB 权限、Audio Interface 数量、claim 能力和原始描述符长度。 |
| 固定采样率输出 | 部分接入 | 偏好已用于 `preferredExclusiveSampleRate()` 和系统 preferred output 请求；真实独占写流仍要看底层能力是否支持对应采样率。 |
| PCM 位深偏好 | 部分接入 | `UsbAudioPreferences.preferredEncoding()` 会把 `16/24/32 bits` 映射到 Android PCM encoding，用于输出偏好请求。 |
| USB 独占播放状态 | 已接入 | `UsbExclusivePlaybackState` 由 start/pause/resume/seek/stop 和约 250ms 的位置更新回传，承载真实播放状态、格式、位深和音量处理字段；缓冲水位另由专门的 `UsbTransportTelemetry` 上报。 |
| 前台缓冲区 / 后台缓冲区 | 已接入 | App 生命周期变化和设置修改会把当前目标水位传给 native 独占引擎；传输状态卡按前台/后台目标计算进度与低水位阈值，不再只是保存偏好。 |
| 后台保活 | 已接入偏好 | 偏好已持久化，并用于 App 内 USB 输出策略判断；是否能完全防止系统杀后台取决于系统电池策略。 |
| 播放后释放 USB 带宽 | 已接入偏好 | 偏好已保存，供停止播放后释放 USB 资源策略使用。 |
| DSD 模式和 DSD 转 PCM 采样率 | 部分接入 | `.dsf/.dff` 已进曲库（`dsd_metadata.dart` 手工解析头部与 DSF 尾部 ID3）。`PCM` 模式：DSD 文件不进独占，由共享路径（mpv）解码转 PCM，DSD64/128/256/512 转 PCM 目标采样率作为系统 preferred output 请求生效。`DoP` 模式：独占链路已实现（`DsdFileReader`→`DopPacketizer`→ISO 打包，时钟设为 DSD 速率÷16，需设备提供 24/32-bit alt），暂停发 DoP 封装的 0x69 静音、seek/切歌不断流。`Native` 模式：描述符声明 RAW_DATA alt（UAC2 bmFormats D31）或 quirk 指定 `nativeDsd.format` 时按字节排列（u8/u16le/u32le/u32be）直发原始 DSD（时钟 SET_CUR 为容器帧率，DSD128 u32le→176400，与 ALSA runtime rate 语义一致），判定失败自动降级 DoP 并在 state message 注明原因；会话级编码器/空窗静音填充/不 flush 策略与 DoP 一致。真机验证待做（Macaron 是否声明 RAW_DATA 以新包诊断报告/日志为准；未声明时自动回退 DoP，可通过 quirk `nativeDsd.format` 强制指定排列试验）。 |
| ReplayGain | 已接入 | 设置可选按音轨、按专辑或关闭；首选标签缺失时回退另一类标签，并结合 peak/当前用户音量限制输出余量。共享输出通过播放器 `volume-gain` 应用；USB PCM 数字音量、标准硬件音量和已实现的厂商协议都接收同一首歌的 ReplayGain。曲目切换、模式切换以及云端缓存成功补齐并落库标签后会立即重新计算当前歌曲，不修改 DoP/Native DSD 码流。 |
| 硬件音量协议与安全回退 | 已接入 | 标准 UAC1/UAC2 Feature Unit 支持能力探测、GET/RANGE、SET 后 readback、多声道失败回滚；状态中的 raw、gain 和 `readbackVerified` 来自实际读回，不使用请求值冒充。厂商协议通过 `UsbVolumeProtocol` 能力抽象选择，由精确 quirk 启用，不按厂商 VID 猜测。iBasso 多寄存器写入任一阶段失败会尝试完整事务回滚；HID 响应持续失败时只在旧 reader 退出后重启一次，再失败则诚实标为 `writeOnly=true, readbackVerified=false`。PCM 可回退数字音量，DSD 不修改码流。 |
| DAC 外置按钮双向同步 | 已接入代码，待本轮真机验收 | `ibassoDc03Pro` 已实现 HID IN command response、写确认和 unsolicited/button event 分流，事件去抖后把 DAC 实际左右声道音量同步到 App、音量浮层和 MediaSession；DAC 主动事件不会再次写回 DAC，避免反馈环。当前协议与自动测试已接入，Macaron 外置按钮全场景仍需本轮真机验收；其他设备只有在协议明确声明 unsolicited 能力后才能启用。 |
| 手机后台/熄屏物理音量键 | 已接入代码，待本轮真机验收 | USB 独占且真实硬件音量或 PCM 数字音量有效时，audio_service 发布 0–100 绝对远程音量，由 MediaSession 在 App 后台/熄屏处理手机物理键并下发同一音量链路；相同 playback info 已去重。RAW、非独占、以及无硬件音量的 1-bit DSD 使用本地系统音量；退出独占立即恢复 `LocalAndroidPlaybackInfo`。旧 Activity 前台按键拦截已删除。黑屏、退到后台和退出 App 后的系统行为待本轮真机验收。 |
| DSD 增益补偿 | 已接入已验证协议 | 偏好范围会随播放请求和运行中调整下发。对 `ibassoDc03Pro`，补偿按每步 `0.5 dB` 换算并只写 DAC 的 DSD 音量寄存器；PCM 寄存器、DoP 标记和 Native DSD 原始数据均不修改。厂商协议必须声明 `dsdGain` 能力且 quirk 未禁用；标准 UAC 还必须由 quirk 显式设置 `dsdSupported:true`，未知能力一律不调整 DSD 增益。 |
| 音量平滑交接 | 已接入 | 新建可读硬件音量连接时先读取 DAC 当前值；启用平滑交接则采用设备实际音量同步 App，避免连接瞬间覆盖。PCM 在数字与硬件路径切换时使用 6 步、每步 20ms 的增益斜坡；退出硬件模式先建立数字衰减，再恢复 DAC 满电平。DSD 不做软件斜坡，避免修改 1-bit 数据。 |
| 真实音量处理状态显示 | 已接入 | 页面直接读取 native state 的 `hardwareVolumeActive`、`digitalVolumeActive`、协议、write-only/readback 状态和 ReplayGain，而不是根据设置选项猜测；实际回退数字音量时显示数字音量，已验证 DAC 控制时显示硬件音量，未验证/未应用会明确标注。 |
| DAC quirk 配置 | 已接入 | 内置 `assets/usb_dac_quirks.json` + 本地 override（设置页“导入 quirk 配置”粘贴 JSON），匹配优先精确 VID/PID。当前生效字段：`dop.supported/maxDsd`、`clock.setCurDelayMs/skipGetCurValidation`、`nativeDsd.format/maxDsd`，以及 `hardwareVolume.enabled/dsdSupported/featureUnitId/controlInterface/channels/protocol/recipient/range`。厂商默认项仅能承载逐产品验证的共同能力，私有硬件音量协议必须精确匹配。诊断报告包含 quirk 匹配/加载错误、Feature Unit 探测、实际 hardware/digital/writeOnly/readback 状态和 RAW_DATA alt。 |
| 云端来源独占策略 | 已接入（待真机验证） | Navidrome/WebDAV/Emby 未缓存曲目：后台下载缓存，约 10 秒水位且下载速度跟得上时用 `.part` 文件流式独占（引擎按增长中的文件读取，数据没跟上时 PCM 按暂停处理、DoP 垫 0x69 静音，不断流不爆音）；4 秒内达不到水位回退共享流式立即出声。独占开启时预取队列下一首云端歌曲，连播场景直接整首缓存走独占。PCM 独占的 seek/手动切歌/停止一律不 `flushOutput`（与 DoP/native 同策略）：丢在途 URB 会瞬断 ISO 流产生小音爆，改为旧缓冲放完后无缝续上新位置/新曲，代价是 seek/切歌延迟约一个水位（海贝同款行为）。流式独占（`.part` 下载未完成）读到数据末尾（seek 落在尚未下载的区段、或顺序播到当前下载末尾）时**不再误判成播放结束去跳下一首**：回到当前位置每 80ms 重探一次，等下载推进后继续（缓冲等待，可被停止/暂停/新 seek 打断）。此前 `getSize()` 返回 -1 使 `MediaExtractor` seek 到未下载时间点直接判 EOS→`readSampleData` 返回 -1→`completed`→跳歌+DAC 重锁爆音。 |

## 参考或占位项

| 项目 | 状态 | 当前用途 |
| --- | --- | --- |
| 位深兼容 | UI/偏好占位 | 可保存，用于后续在独占链路里按 DAC 能力回退位深。当前不直接改变 PCM 数据写入。 |
| 采样率兼容 | UI/偏好占位 | 可保存，用于后续按 DAC 支持列表自动回退采样率。当前主要还是固定采样率和系统 preferred output 在生效。 |
| 声道兼容 | UI/偏好占位 | 可保存，用于后续处理单声道/多声道回退。当前不做实际声道重排。 |
| TPDF 抖动 | UI/偏好占位 | 可保存，但当前没有接入高位深转 16-bit 的音频处理链路。 |
| 延迟建立 USB 输出链路 | UI/偏好占位 | 可保存，用于后续把 claim/open endpoint 推迟到播放开始。当前不改变建链时机。 |
| USB 总线速度 | UI/偏好占位 | 可保存，用于后续诊断或策略选择。普通 Android App 通常不能强制 USB bus speed。 |
| DAC 端点格式 | 信息占位 | 无独占播放时显示系统/设备能力；真实 endpoint alt setting 需要底层能力解析后再展示。 |

## 传输状态卡说明

传输状态卡已经接入独立的真实 telemetry，不再把播放位置或固定 `ISO 0` 当作缓冲状态：

- 主数值：native USB 队列计算出的 `bufferLevelMs`。
- 状态：结合 active/playing、当前水位、最近欠载时间和目标水位显示待机、暂停、稳定、低水位或欠载；历史欠载不会永久锁住当前状态。
- 目标：按 App 前后台状态选取对应缓冲偏好，并实时下发 native 引擎。
- 最低：播放会话中 native 记录的非零最低缓冲水位；没有有效样本时显示 `最低 --`。
- ISO 统计：底层继续记录 `isoPacketCount`、`pendingUrbs`、`underrunCount` 并写入诊断报告，但页面不再显示对用户无解释价值的 ISO 数字。

状态卡仍是诊断辅助，不代表端到端声学延迟；实际延迟还包含解码、USB 控制器、DAC FIFO 和模拟输出阶段。
