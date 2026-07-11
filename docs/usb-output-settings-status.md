# USB 输出设置接入状态

本文档记录 `USB 输出设置` 页面里哪些项目已经接入真实链路，哪些只是先放在 UI 和偏好层，作为后续 USB 独占链路改造的参考。

## 已接入运行链路

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| Android USB 插入声明 | 已接入 | `AndroidManifest.xml` 已声明 `android.hardware.usb.action.USB_DEVICE_ATTACHED`，`usb_audio_device_filter.xml` 已包含 USB Audio Class 和 Macaron VID/PID。`dumpsys usb` 能看到 `com.afalphy.sylvakru.debug` 注册到 `device_attached_activities`。 |
| USB 设备识别 | 已接入 | 通过 Android 侧 USB/AudioDevice 状态回传，设置页能显示 DAC 名称、USB ID、系统输出设备、采样率和编码等信息。 |
| USB 权限与独占诊断 | 已接入 | `probeExclusiveAccess()` 会检查 USB 权限、Audio Interface 数量、claim 能力和原始描述符长度。 |
| 固定采样率输出 | 部分接入 | 偏好已用于 `preferredExclusiveSampleRate()` 和系统 preferred output 请求；真实独占写流仍要看底层能力是否支持对应采样率。 |
| PCM 位深偏好 | 部分接入 | `UsbAudioPreferences.preferredEncoding()` 会把 `16/24/32 bits` 映射到 Android PCM encoding，用于输出偏好请求。 |
| USB 独占播放状态 | 已接入快照 | `UsbExclusivePlaybackState` 会由 start/pause/resume/seek/stop 等 native 调用回传，页面监听这个 notifier 展示当前快照。它不是连续实时水位。 |
| 后台保活 | 已接入偏好 | 偏好已持久化，并用于 App 内 USB 输出策略判断；是否能完全防止系统杀后台取决于系统电池策略。 |
| 播放后释放 USB 带宽 | 已接入偏好 | 偏好已保存，供停止播放后释放 USB 资源策略使用。 |
| DSD 模式和 DSD 转 PCM 采样率 | 部分接入 | `.dsf/.dff` 已进曲库（`dsd_metadata.dart` 手工解析头部与 DSF 尾部 ID3）。`PCM` 模式：DSD 文件不进独占，由共享路径（mpv）解码转 PCM，DSD64/128/256/512 转 PCM 目标采样率作为系统 preferred output 请求生效。`DoP` 模式：独占链路已实现（`DsdFileReader`→`DopPacketizer`→ISO 打包，时钟设为 DSD 速率÷16，需设备提供 24/32-bit alt），暂停发 DoP 封装的 0x69 静音、seek/切歌不断流。`Native` 模式：描述符声明 RAW_DATA alt（UAC2 bmFormats D31）或 quirk 指定 `nativeDsd.format` 时按字节排列（u8/u16le/u32le/u32be）直发原始 DSD（时钟 SET_CUR 为容器帧率，DSD128 u32le→176400，与 ALSA runtime rate 语义一致），判定失败自动降级 DoP 并在 state message 注明原因；会话级编码器/空窗静音填充/不 flush 策略与 DoP 一致。真机验证待做（Macaron 是否声明 RAW_DATA 以新包诊断报告/日志为准；未声明时自动回退 DoP，可通过 quirk `nativeDsd.format` 强制指定排列试验）。 |
| 硬件音量和 DSD 增益补偿 | 部分接入 | UAC1/UAC2 Feature Unit 已接入安全自动探测、SET/GET 回读、多声道回滚和 PCM 数字音量回退；DoP/Native DSD 仅使用已验证的硬件控制，不修改码流。DSD 增益补偿仍只持久化偏好。 |
| DAC quirk 配置 | 已接入 | 内置 `assets/usb_dac_quirks.json` + 本地 override（设置页"导入 quirk 配置"粘贴 JSON），`vid:pid` 精确 → `vid:*` 厂商 → 默认三级匹配。当前生效字段：`dop.supported/maxDsd`（DoP 判定）、`clock.setCurDelayMs/skipGetCurValidation`（时钟配置）、`nativeDsd.format/maxDsd`（Native DSD 排列与上限判定）、`hardwareVolume.enabled/dsdSupported/featureUnitId/controlInterface/channels`（硬件音量选择与禁用）。诊断报告含 quirk 匹配结果、加载错误、硬件音量探测与各 alt 的 RAW_DATA 标记。 |
| 云端来源独占策略 | 已接入（待真机验证） | Navidrome/WebDAV/Emby 未缓存曲目：后台下载缓存，约 10 秒水位且下载速度跟得上时用 `.part` 文件流式独占（引擎按增长中的文件读取，数据没跟上时 PCM 按暂停处理、DoP 垫 0x69 静音，不断流不爆音）；4 秒内达不到水位回退共享流式立即出声。独占开启时预取队列下一首云端歌曲，连播场景直接整首缓存走独占。PCM 独占的 seek/手动切歌/停止一律不 `flushOutput`（与 DoP/native 同策略）：丢在途 URB 会瞬断 ISO 流产生小音爆，改为旧缓冲放完后无缝续上新位置/新曲，代价是 seek/切歌延迟约一个水位（海贝同款行为）。流式独占（`.part` 下载未完成）读到数据末尾（seek 落在尚未下载的区段、或顺序播到当前下载末尾）时**不再误判成播放结束去跳下一首**：回到当前位置每 80ms 重探一次，等下载推进后继续（缓冲等待，可被停止/暂停/新 seek 打断）。此前 `getSize()` 返回 -1 使 `MediaExtractor` seek 到未下载时间点直接判 EOS→`readSampleData` 返回 -1→`completed`→跳歌+DAC 重锁爆音。 |

## 参考或占位项

| 项目 | 状态 | 当前用途 |
| --- | --- | --- |
| 位深兼容 | UI/偏好占位 | 可保存，用于后续在独占链路里按 DAC 能力回退位深。当前不直接改变 PCM 数据写入。 |
| 采样率兼容 | UI/偏好占位 | 可保存，用于后续按 DAC 支持列表自动回退采样率。当前主要还是固定采样率和系统 preferred output 在生效。 |
| 声道兼容 | UI/偏好占位 | 可保存，用于后续处理单声道/多声道回退。当前不做实际声道重排。 |
| TPDF 抖动 | UI/偏好占位 | 可保存，但当前没有接入高位深转 16-bit 的音频处理链路。 |
| 前台缓冲区 / 后台缓冲区 | UI/偏好占位 | 可保存，并用于设置页显示目标水位；当前未接入底层 USB isochronous 写入队列。 |
| 音量平滑交接 | UI/偏好占位 | 当前切换会按同一线性增益映射硬件 dB，并在退出硬件模式时恢复硬件满刻度；淡入淡出策略仍未接入。 |
| 延迟建立 USB 输出链路 | UI/偏好占位 | 可保存，用于后续把 claim/open endpoint 推迟到播放开始。当前不改变建链时机。 |
| USB 总线速度 | UI/偏好占位 | 可保存，用于后续诊断或策略选择。普通 Android App 通常不能强制 USB bus speed。 |
| DAC 端点格式 | 信息占位 | 无独占播放时显示系统/设备能力；真实 endpoint alt setting 需要底层能力解析后再展示。 |

## 传输状态卡说明

传输状态卡现在按快照表达，不再伪装成实时仪表：

- 主数值：`UsbExclusivePlaybackState.position`，目前代表 native 回传的播放/水位快照。
- 状态：`active + playing` 显示为稳定，`active + !playing` 显示为暂停，否则为待机。
- ISO：当前没有底层 isochronous 传输实时计数，固定显示 `ISO 0`。
- 目标：来自前台缓冲区偏好，默认 `200 ms`，只作为目标水位参考。
- 最低：当前没有底层最低水位统计，播放中暂用本次快照值；待机显示 `最低 --`。

如果后续要让它真正实时，需要 native 层周期性上报 USB 写入队列水位、iso packet 计数、underrun 次数和最低水位，再更新 `UsbExclusivePlaybackState` 或新增专门的传输 telemetry notifier。
