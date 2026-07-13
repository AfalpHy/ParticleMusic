# USB DAC 适配指南（独占 / DoP / Native DSD）

本指南供两类读者使用：
- **人**：按第 1–6 节理解链路、读诊断报告、按症状表定位问题；
- **AI**：直接跳到第 7 节「AI 快速适配协议」，配合用户提供的诊断报告输出 quirk JSON 或代码改动建议。第 1–6 节是协议的知识库，遇到不确定时回来查。

适配的核心思路是 **capability-first（能力优先）**：先用描述符、只读探测、厂商应用日志和真机回读证明设备实际使用的能力与协议，再决定是否需要代码和 quirk。VID、PID、`bcdDevice`、厂商名和产品名只用于建立设备指纹，不能替代协议证据。绝大多数已支持差异可通过 quirk JSON（用户在设置页粘贴导入，立即生效、无需发版）解决；只有发现新的协议类别时才加代码。

> **禁止仅凭厂商 VID 泛化硬件音量协议。** 同一厂商、甚至外观相近的产品也可能分别使用 UAC Feature Unit、HID、Bulk 或完全不同的 vendor control。未经逐产品证据验证，不得把单台设备的协议扩成 `vid:*`。

## 0. 能力优先适配闭环

每台新 DAC 都按以下顺序取证；前一步证据不足时，不得跳到猜写寄存器：

1. **建立指纹**：记录 VID、PID、`bcdDevice`、manufacturer、product 和可用的 serial。它们只负责匹配设备，不证明能力。
2. **保存原始描述符**：保留完整 configuration/interface/endpoint、AudioControl、AudioStreaming、HID report descriptor 的原始十六进制，不只保留 App 的解析摘要。
3. **判别控制类型**：依次检查标准 UAC Feature Unit、HID feature/input/output report、Bulk/Interrupt endpoint、自定义 vendor/class control transfer。先判类别，再谈字段含义。
4. **安全只读 GET**：仅发送厂商实现、规范或抓包已证明安全的 GET/读命令；记录完整请求七元组和原始返回值。未知命令不得以“只读看起来安全”为由试发。
5. **原样写回并立即读回**：取得用户许可后执行“读当前值 → 原样写回 → 立即读回”，验证写链路而不改变响度。返回长度成功不等于语义正确。
6. **捕获主动事件**：分别记录 App 写入确认、DAC 外置音量按钮、旋钮和 mute 操作产生的 unsolicited HID/interrupt/bulk 事件，区分“写确认”和“设备主动变化”。
7. **还原数值模型**：确认范围、步进、静音值、左右声道/主声道关系、端序、有符号格式，以及 UI 级数到寄存器或 dB 的映射。
8. **实现精确协议**：只有第 3–7 步证明现有 UAC 路径无法表达时，才在 `UsbVolumeProtocol` 增加一个有能力声明、编码、解码和事件识别的精确协议实现。
9. **添加精确 quirk**：先匹配完整 VID/PID；只有多款产品分别验证为同一协议后，才考虑受控的厂商默认项。未知协议必须安全回退数字音量或本地系统音量。
10. **完成测试与诊断附件**：跑纯逻辑/协议包/状态映射自动测试和 PCM、DSD、外置按钮、拔插、失败回退真机矩阵；随适配提交原始描述符、关键英文日志、诊断报告和最小 quirk。

适配完成的标准不是“SET 返回成功”，而是写入、readback、实际响度、主动事件、左右声道和失败回退形成闭环，且诊断状态诚实反映 `hardware`、`digital`、`writeOnly` 与 `readbackVerified`。

---

## 1. 链路架构速览

```
音频文件
  ├─ PCM(flac/wav): MediaExtractor/MediaCodec 解码 ──┐
  └─ DSD(dsf/dff): DsdFileReader（统一输出 MSB-first │
       逐字节声道交错的 DSD 流）                      │
         ├─ DoP:    DopPacketizer（2字节/声道/帧 +   │
         │          0x05/0xFA 标记 → 24-bit PCM 帧）  ├─ PcmIsoPacketizer
         └─ Native: NativeDsdPacketizer（按 u8/u16le/ │   （水位/反馈节奏，
                    u32le/u32be 重排 subslot）        │    slot 位深转换）
                                                      ↓
                              UsbExclusiveNative(cpp) ISO URB 提交/回收
                                                      ↓
                                              USB DAC（claim 接口 + altsetting + UAC 时钟）
```

关键文件（都在 `android/app/src/main/`）：
| 文件 | 职责 |
| --- | --- |
| `kotlin/.../UsbExclusiveAudioEngine.kt` | 会话生命周期、alt 选择（`findOutputTarget`）、UAC1/2 时钟（`configureUsbAudioClock`）、DoP/native 判定（`start`）、写线程 |
| `kotlin/.../UsbDsd.kt` | DSF/DFF 解析、DoP/native 编码器（纯 Kotlin，JVM 单测覆盖） |
| `kotlin/.../UsbDacQuirks.kt` | quirk 加载与匹配 |
| `cpp/usb_exclusive_engine.cpp` | USBDEVFS ISO URB 提交/回收、反馈端点、flushOutput |
| `assets/usb_dac_quirks.json` | 内置 quirk 表（override 文件优先于它） |

**三条铁律（真机踩坑总结，违反必出问题）**：
1. **DSD 流（DoP 或 native）一旦中断，DAC 就掉出 DSD 模式再重锁**（指示灯变色 + 继电器咔嗒/电流声）。所以 DoP/native 会话：切歌/seek/停止一律**不 flushOutput**、空窗期由常驻静音线程垫 0x69、编码器提升会话级保持相位连续。
2. **DSD 样本一个 bit 都不能改**。音量、抖动、重采样、位深移位都会把 DoP 变成全幅噪声、把 native 变成垃圾。DSD 静音是 `0x69` 不是 `0x00`。
3. **时钟 SET_CUR 一律用容器帧率**（= ALSA runtime rate）：PCM 用采样率；DoP 用 DSD速率÷16；native 用 DSD速率÷8÷每采样字节数（DSD128 u32le → 176400）。**不是**字节率——Macaron 实测设字节率会被无视，DAC 停在旧时钟上持续欠载（表现为不间断电流声）。

## 2. 诊断报告怎么读

用户路径：设置 → USB 输出设置 → 支持 → 生成诊断报告（一键复制）。报告不要求 DAC 正在播放，但**建议在"问题刚复现后"生成**，日志节里会带最近的独占日志。

按节解读（节名以报告实际输出为准）：

| 报告节 | 关键字段 | 怎么用 |
| --- | --- | --- |
| Device | vendor/product id | 写 quirk `match` 用；十六进制 |
| Raw descriptors (hex dump) | 完整配置描述符 | 终极依据；AS_GENERAL(子类型 0x01) 第 7–10 字节是 bmFormats |
| App parse result → AS formats | 每个 alt 的 `subslotSize/bitResolution/bmFormats` | `bmFormats=-2147483648`(0x80000000, D31) = **RAW_DATA = native DSD alt**；`bmFormats=1` = 普通 PCM |
| App parse result → Output candidates | `alt/max/feedback/usbBytes/bits/raw` | `raw=true` 的候选就是 native alt；`max`(maxPacket) 决定该 alt 能跑的最高速率；`feedback=none` 表示同步/自适应端点（无异步反馈） |
| App parse result → Quirk | Match / Effective / Load errors | 当前命中的 quirk 条目与生效值；Load errors 非空说明导入的 JSON 有问题 |
| UAC2 clock source id | clockSourceId | null 时走 UAC1 端点式 SET_CUR |
| Exclusive session | input / outputSelections / clock / feedback / transport | 最近一次独占会话的真实请求、alt 候选与选择、时钟读写、反馈和提交统计；远程适配优先看这一节 |
| Hardware volume probe | featureUnits / probes / quirkOverride | Feature Unit、声道、可写状态、当前值和范围；会话节的 `hardwareVolume` 记录实际选择、SET/GET 与回退原因 |
| 运行状态快照 | format/sampleRate/bitDepth/message | `message` 里有回退原因（如 native 降级 DoP 的原因） |
| Telemetry | bufferLevelMs/underrunCount/pendingUrbs | underrun 持续增长 = 供数或时钟问题 |

**报告之外还需要什么**：细粒度时序问题（周期性咔嗒、反馈异常）要配 logcat。先把下面的包名变量替换为实际安装包名，例如正式版 `com.afalphy.sylvakru` 或调试版 `com.afalphy.sylvakru.debug`。

Windows PowerShell（`Select-String` 和 `Set-Content` 在电脑主机上执行，不在 `adb shell` 内执行）：

```powershell
$package = 'com.afalphy.sylvakru'
$appPid = (adb shell pidof $package).Trim()
adb logcat -d --pid=$appPid | Select-String -Pattern 'UsbExclusive|SylvakruUsb' | Set-Content -Encoding utf8 usb.log
```

Bash / Git Bash：

```bash
package='com.afalphy.sylvakru'
adb logcat -d --pid="$(adb shell pidof "$package")" | grep -E "UsbExclusive|SylvakruUsb" > usb.log
```

日志里最有诊断价值的行：
- `USB AS formats parsed:` —— 描述符解析结果（同报告）；
- `selected USB alt=…` —— 实际选中的 alt 与原因链；
- `UAC2 clock SET_CUR/GET_CUR` —— 时钟是否被接受（注意：**GET_CUR 返回 0 不代表失败**，很多 DAC 不回报，只有"非零且不等于请求值"才算拒绝）；
- `USB feedback actual=… approxFrames=…` —— DAC 实际消耗速率。**approxFrames ≈ 请求采样率 ÷ 包率** 才是健康的；差一倍/几倍 = 时钟没被接受或反馈格式解析错了；
- `USB feedback ignored` —— 反馈值超出合理窗被丢弃；偶发几条（时钟刚切换）正常，持续出现 = 反馈格式或时钟问题；
- `USB write stats bytes=… pendingUrbs=…` —— 每秒一条；bytes 增速应等于数据率（DSD128≈1.41MB/s），pendingUrbs 稳定 = 传输健康。

## 3. 三条链路的判定流程（代码现状）

### 3.1 PCM 独占（flac/wav）
1. Dart 侧：源采样率必须在支持列表内（无 SRC，不匹配直接回退系统输出）；
2. `findOutputTarget` 按 maxPacket 是否装得下 `采样率×声道×slot字节` 选 alt，位深偏好 24→32→16；
3. 时钟 SET_CUR + GET_CUR 校验（quirk 可加延时/跳过校验）。

### 3.2 DoP
1. DoP 对 DAC 是透明 PCM，**描述符无法声明支持与否**。判定顺序：quirk `dop.supported`（false 直接拒绝，true 直接用）→ 无 quirk 则检查硬性条件（24/32-bit slot + DoP 帧率有 alt 能承载）满足就试播；
2. 帧率 = DSD速率÷16（DSD64→176.4k，DSD128→352.8k）；设备最高 PCM 率决定 DoP 上限（只支持 384k 的设备最高 DoP128）；
3. 16-bit-only 设备物理上不可能 DoP（标记+数据要 24 bit）。

### 3.3 Native DSD
1. 判定：quirk `nativeDsd.format` 优先 → 描述符有 `raw=true` 的 alt 则按其 subslot 推断（4 字节→u32le，2→u16le，1→u8；**默认小端**，大端设备极少、目前只见于 Marantz/Denon 系，靠 quirk 指定 u32be）；
2. 帧率 = DSD速率÷8÷subslot 字节数；时钟 SET_CUR 用这个帧率（铁律 3）；
3. 选中 alt 必须与推断的 subslot **同宽**（不允许位深转换）；
4. 任一步失败 → **自动降级 DoP**（state message 注明原因）→ DoP 也不行 → Dart 回退共享输出。

## 4. quirk 字段全表（症状 → 字段）

内置目录按厂商分组保存；`match.vid/pid` 为十六进制字符串。格式允许 `pid: "*"` 表示厂商默认规则，但它只适用于已经逐产品验证的共同属性，**不得用来推断硬件音量协议**。首次适配始终使用精确 VID/PID；手动导入仍兼容旧版平铺 `devices` JSON。

```json
{
  "version": 2,
  "vendors": [
    {
      "match": { "vid": "0x262a", "label": "厂商名" },
      "devices": [
        {
          "match": { "pid": "0x9302", "label": "设备名（可选）" },
          "dop": { "supported": true, "maxDsd": 256 },
          "nativeDsd": { "format": "u32le", "maxDsd": 512 },
          "clock": { "setCurDelayMs": 50, "skipGetCurValidation": true },
          "hardwareVolume": {
            "enabled": true,
            "dsdSupported": true,
            "featureUnitId": 7,
            "controlInterface": 0,
            "channels": [0, 1, 2],
            "protocol": "uac2",
            "recipient": "interface",
            "range": {
              "minDb": -63,
              "maxDb": 0,
              "stepDb": 1,
              "muteDb": -112
            }
          }
        },
        {
          "match": { "pid": "*" },
          "clock": { "setCurDelayMs": 30 }
        }
      ]
    }
  ]
}
```

| 字段 | 解决什么症状 |
| --- | --- |
| `dop.supported: false` | 该设备 DoP 输出是噪声（不支持 DoP），强制走 PCM/回退 |
| `dop.supported: true` | 跳过试播确认，直接认定支持 |
| `dop.maxDsd` | DoP 到某速率（如 DSD256）变噪声/无声，限制上限 |
| `nativeDsd.format` | 设备支持 native 但描述符没声明 RAW_DATA（Amanero 等常见），或声明了但默认推断的排列不对（音乐位置对但内容是噪声→试 u32be；完全乱→试 u16le/u8） |
| `nativeDsd.maxDsd` | native 高倍率失败，限制上限 |
| `clock.setCurDelayMs` | 起播头几百毫秒爆音/变调后恢复——DAC SET_CUR 后需要时间锁定，加 30–100ms |
| `clock.skipGetCurValidation` | 明明能正常播却被判"DAC 未接受采样率"回退——GET_CUR 返回垃圾值（非零且≠请求值）的设备 |
| `hardwareVolume.enabled` | Feature Unit 声明异常、写入不安全或硬件音量实际无效时设 `false`，强制回退 |
| `hardwareVolume.dsdSupported` | PCM 硬件音量正常但 DoP/Native DSD 不响应时设 `false`；确认 DSD 可调时可设 `true` 留档 |
| `hardwareVolume.featureUnitId` | 描述符漏报、候选不唯一或实现异常时指定硬件音量 Feature Unit |
| `hardwareVolume.controlInterface` | 指定 Feature Unit 所在的 AudioControl 接口号 |
| `hardwareVolume.channels` | 指定主声道 `0` 或需要同步的逻辑声道；多声道会逐个 SET/GET，任一失败自动回滚 |
| `hardwareVolume.protocol` | `uac1`/`uac2` 用于覆盖 GET_CUR 的 bRequest（分别为 `0x81`/`0x01`）；已实现的厂商私有协议使用专用名称，如 `ibassoDc03Pro` |
| `hardwareVolume.recipient` | 默认 `interface`（标准 UAC，requestType `0x21/0xA1`）；隐藏厂商实体若使用设备接收者则填 `device`（`0x20/0xA0`） |
| `hardwareVolume.range.minDb/maxDb/stepDb` | 描述符不公开 Feature Unit、GET_RANGE 不可用时，提供厂商已验证的固定 Q8.8 dB 范围；三项必须同时存在 |
| `hardwareVolume.range.muteDb` | 厂商静音值；缺省沿用标准 `0x8000`，不得把普通最小音量猜成静音 |

导入方式：设置 → USB 输出设置 → 支持 → 导入 quirk 配置 → 粘贴 JSON → 重连设备。override 与内置表同 vid:pid 时 override 优先，便于反复试验。验证通过的条目应回传开发者合入内置表。

### 4.1 硬件音量厂商适配流程

先判断控制属于哪一类，不能看到“音量可调”就假设存在标准 Feature Unit：

| 能力类别 | 必需证据 | 实现方式 |
| --- | --- | --- |
| 标准 UAC Feature Unit | 原始 AC 描述符有 `CS_INTERFACE / FEATURE_UNIT (subtype 0x06)`；唯一播放候选的 `GET_CUR`、范围读取和原样 SET/GET 成功 | 优先自动探测；仅候选不唯一时用 `featureUnitId/controlInterface/channels` 精确覆盖 |
| 隐藏 UAC 实体 | 厂商应用日志证明 `wValue=0x02cc`、`wIndex=0xUUII`、两字节 Q8.8 dB，并取得 recipient、范围、声道和 mute 证据 | 用现有 UAC 实现加精确 quirk；不在引擎写 VID/PID 特判 |
| HID | 原始 HID/report descriptor、SET_REPORT/GET_REPORT 或 interrupt IN/OUT 包；能区分命令响应、写确认和 unsolicited 按钮事件 | 实现精确 `UsbVolumeProtocol`，声明 readable/unsolicited/DSD 能力，再由精确 quirk 选择 |
| Bulk / Interrupt 私有报文 | endpoint、方向、包长、超时和厂商应用 `bulkTransfer` 日志；原样写回与读回闭环 | 新增经过包级测试的精确协议，失败时安全回退 |
| Vendor/Class control | 完整 `requestType/request/value/index/length/timeout/data`，以及实际响度和 readback 证明 | 只有字段语义已证实时才能实现；返回长度成功不能作为协议证据 |

I²C 寄存器可能只是 HID 或 vendor 报文内部的负载格式，不等于 Android 可以直接访问 I²C。必须先实现其 USB 承载协议，禁止把私有报文硬塞进 UAC 音量字段。

标准 UAC 成功写入后，状态和诊断必须发布每个 Feature Unit 声道的实际 GET_CUR 读回结果，并以最低实际增益声道作为保守 raw/gain；不得把请求目标值当成 DAC 实际值。只有完整读回通过时才能报告 `readbackVerified=true`。DSD 还需额外能力证据：厂商协议要求自身声明 `dsdGain` 且 quirk 未禁用，标准 UAC 则要求 quirk 显式设置 `hardwareVolume.dsdSupported:true`；未知能力不允许调整 DSD 增益。

#### 证据获取顺序

按“只读优先、一次只验证一个变量”执行：

1. 诊断报告取 VID/PID、`bcdDevice`、产品名、原始描述符、当前 quirk、`Hardware volume probe` 和 `hardwareVolume.fallbackReason`。
2. 查系统能力：Windows `IAudioEndpointVolume.QueryHardwareSupport=0` 只表示系统未识别标准硬件音量，**不能排除隐藏厂商控制**。
3. 有厂商 Android 软件时，静态搜索：`UsbDeviceConnection`、`controlTransfer`、`bulkTransfer`、`SET_CUR`、`GET_CUR`、`SET_REPORT`、`vendorId/productId/productName`。记录全部七元组：`requestType/request/value/index/length/timeout/data`。
4. root 真机先做 GET：找到 `/dev/bus/usb/BBB/DDD`，只读厂商 `GET_CUR`；再用标准 recipient 做对照。返回长度必须等于数据长度，数据语义必须稳定。
5. 用户明确同意后才做“读当前值 → 原样写回 → 立即读回”。这一步证明写通路，不改变响度。真正改变音量必须低音量、逐级测试，并保存左右声道原值用于失败回滚。
6. 保持监听并分别操作 DAC 外置按钮/旋钮与 App 滑块，保存原始 unsolicited 包；确认左右声道、mute、边界级数和连续按键去抖，避免把写确认回环当成设备主动事件。
7. 先导入单台精确 VID/PID override；PCM 验证通过后再验证 DoP/Native DSD。不同产品名走不同厂商控制类时，不得直接写 VID 通配规则。
8. 用测试矩阵验证 0/25/50/100%、左右一致、mute/unmute、App→DAC、DAC→App、暂停/切歌、读失败/写失败/拔插回退；最后附诊断报告、描述符和关键英文日志。

#### controlTransfer 解码速查

- `requestType`: bit7 为方向（IN=`0x80`），bit6..5 为类型（CLASS=`0x20`），bit4..0 为接收者（DEVICE=`0`、INTERFACE=`1`）。因此类设备常见 `0x20/0xA0` 或标准 `0x21/0xA1`。
- `recipient=device` 的隐藏实体要继续核对厂商连接方式。若厂商每次控制都 `UsbManager.openDevice()` 后直接传输、不 claim 接口，则必须使用独立控制连接；复用正在等时传输的流连接可能出现 SET 返回成功但 GET 始终读到 `0 dB` 的假镜像值。
- UAC 音量 `wValue = 0x02cc`：高字节 `0x02` 是 VOLUME_CONTROL，低字节 `cc` 是声道号。
- `wIndex = 0xUUII`：高字节 `UU` 是 Feature Unit ID，低字节 `II` 是控制接口号。
- 两字节小端有符号 Q8.8：`-6 dB = 0xFA00`，传输字节为 `00 FA`。
- 多声道设备要先读完全部原值，再依次写入；任一 SET/GET 失败立即按相反顺序回滚，避免左右失衡。

#### Macaron / DC03 Pro 协议已验证示例（不得按厂商泛化）

`iBasso Macaron (262a:1a0b, bcdDevice 0x0060)` 的描述符没有 Feature Unit。iBasso UAC 1.8.6 把它分派给 DC03 Pro 控制器，使用 HID SET_REPORT 承载 I²C 寄存器命令：

```json
{
  "version": 1,
  "devices": [
    {
      "match": { "vid": "0x262a", "pid": "0x1a0b", "label": "iBasso Macaron" },
      "hardwareVolume": {
        "enabled": true,
        "protocol": "ibassoDc03Pro",
        "dsdSupported": true
      }
    }
  ]
}
```

官方软件写入使用 `controlTransfer(0x21, 0x09, 0x0200, 0, packet16, 16, 200)`，并从 HID IN 端点读取响应。一次音量更新会同步写左右 PCM、左右 DSD 和 room 寄存器，再用命令 `65` 回读左声道实际值；Sylvakru 只有在回读一致后才报告硬件音量生效。HID IN 还会主动上报 DAC 外置按钮产生的左右声道值；实现会区分写确认与 unsolicited event，去抖后再同步到 App。厂商软件对 DC03/04/06/07、DC-Elite、DC-Nunchaku 等产品名分派不同控制类，因此这里只验证了 Macaron 使用的 DC03 Pro 协议实现，本条只能精确匹配 `262a:1a0b`，不能扩成整个 `0x262a:*`，也不能据此假设所有 DC 系列包格式相同。

此前尝试的 `0x20 SET_CUR` / `0xA0 GET_CUR` 虽然返回长度 2，但不会改变 DAC 的真实音量，属于“传输成功、语义错误”的假阳性。厂商私有协议必须核对实际响度和厂商读回命令，不能只看 `controlTransfer` 返回值。以下开发者日志保持英文，便于其他 AI 与源码逐字匹配：

```text
iBasso hardware volume set register=..., dsdRegister=..., protocol=ibassoDc03Pro
iBasso hardware volume write confirmation raw=...
iBasso unsolicited hardware volume leftRaw=..., rightRaw=..., actualRaw=..., gainQ16=...
iBasso hardware volume readback mismatch: target=..., actual=...
iBasso hardware volume applied with readback=unavailable, writeOnly=true, register=..., dsdRegister=...
```

成功状态应为 `hardware=true, digital=false`；若旧 HID reader 未能在有界期限内退出，或已重启的 reader 再次失败，诊断必须诚实显示 `writeOnly=true, readbackVerified=false`，不能把“仍可写入”误报成完整双向同步。

Macaron 一次目标更新包含 10 个相关寄存器包，必须作为一个事务处理：开始前保存同连接上次已验证目标，或从新连接的实际读回值派生可信回滚目标；没有可信旧值时不得开始写。任一目标包、命令响应或最终读回失败，都要在关闭控制连接前 best-effort 重发完整 10 包回滚，且只有全组成功（或已明确降级 write-only 后全组写成功）才能更新“最后已应用目标”。HID IN 空闲超时不算故障；只有存在 pending command 时的持续负读或响应超时才触发 reader 健康状态。第一次故障等待旧 reader 在有界期限内完全退出：按时退出才重启一次，超过期限则直接降级 write-only；已重启的 reader 再失败也降级 write-only。旧 generation 的线程、异常和延迟回调不得影响新连接。

Macaron 的官方控制器使用 101 项非线性寄存器表（界面 0–100，寄存器值从静音 `255` 递减到满音量 `0`）。Sylvakru 先反解自身 PCM 的 `volume^1.5` 增益，再映射到同一 0–100 级，因此 90% 对应 90 级；实际显示仍使用统一百分比，不直接显示寄存器值。打开 iBasso UAC 时，它会主动恢复自身保存的级数，因此不能同时打开两个控制软件对比静态数值。

USB 设置中的 DSD 增益补偿只调整 Macaron 的四个 DSD 音量寄存器，按芯片每步 `0.5 dB` 换算；PCM、DoP 标记和 native DSD 数据均不修改。音量平滑交接用于 PCM 在数字音量与 DAC 音量之间切换：接管成功后用短增益斜坡撤掉数字衰减，退出硬件模式时先建立数字衰减再恢复 DAC 满电平，避免瞬间满音量。

## 5. 症状排查表（含本项目真机实录）

| 症状 | 最可能原因 | 定位手段 | 对策 |
| --- | --- | --- | --- |
| 完全无声，无报错 | 时钟没生效 / alt 不对 / 系统仍占着设备 | 日志 feedback approxFrames 是否≈nominal；`selected USB alt` | 见 §2 反馈解读；确认 DISCONNECT_CLAIM 成功 |
| **不间断电流声/杂音（音乐完全听不到）** | 时钟没被接受，DAC 按错误速率消耗（实录：native 时钟误设字节率，反馈 48fpp vs 名义 22fpp） | 反馈 approxFrames 与 nominal 差整数倍 | 检查 SET_CUR 值语义（铁律 3）；`clock.setCurDelayMs` |
| **全幅白噪声（DoP）** | 样本被修改（音量/移位）或设备不支持 DoP | 排除 DSP 后仍噪声 → 设备不支持 | `dop.supported:false` |
| **全幅/大声噪声（native）** | 字节排列错 | 换 `nativeDsd.format`：u32le→u32be→u16le | quirk 试验；都不行降 DoP |
| **切歌/seek 咔嗒+指示灯变色** | DSD 流中断（实录：flushOutput 丢在途 URB 瞬断 ISO 流） | 指示灯蓝→绿→蓝 | DSD 会话禁止 flush；空窗垫 0x69；已内置，若复现查新增代码是否绕过了该策略 |
| 起播瞬间爆音后正常 | 时钟锁定期开流 | 只在起播出现 | `clock.setCurDelayMs: 30~100` |
| 明明能播却总回退"DAC 未接受采样率" | GET_CUR 返回垃圾 | 日志 GET_CUR after 的值 | `clock.skipGetCurValidation: true`（注意 GET_CUR=0 已内置豁免，不需要 quirk） |
| 高速率(352.8k+/DSD256+)失败，低速率正常 | 带宽/maxPacket 或设备上限 | Output candidates 的 max 值 vs 需求 | `dop.maxDsd`/`nativeDsd.maxDsd`；full-speed 设备连 DoP64 都不够属正常拒绝 |
| 周期性轻微"pa pa"声（音乐正常） | 待定类别。二分：暂停（纯 0x69 流）仍有→传输/时钟层；暂停消失→数据重排层；DoP 是否同样有→定位到 native 特有还是共性 | 按左列二分 + 反馈日志 | 按二分结果进一步排查 |
| 选择 DAC 硬件音量但无效 | 无标准 Feature Unit、recipient/Unit/声道不符，或设备只提供 HID 音量键输入 | 报告 `featureUnits/probes/fallbackReason`；厂商 APK 静态搜索；root GET_CUR 对照 | 按 §4.1 建精确 quirk；HID/bulk 协议需要代码扩展，不得猜 UAC 参数 |
| 扫描不到 DSD 文件 | 分区存储：.dsf/.dff 无 MIME 注册，MediaStore 不可见（实录） | 文件管理器可见但 App 列不出 | 已内置扫描前请求所有文件访问权限；确认用户授了权 |
| WebDAV/流媒体 DSD 不识别 | 远程头部解析失败 | — | 已内置 Range 拉头部解析；确认服务端支持 Range |

## 6. 新设备验证阶梯

按顺序执行，每步通过再进下一步；失败即停，按 §5 定位：

1. **PCM 44.1k/16bit flac**：出声、暂停/恢复、seek、切歌无异常；
2. **PCM 最高采样率**（设备声明的上限）：无变调、无欠载（telemetry underrun 不增长）；
3. **DoP DSD64**：DAC 面板亮 DSD 标识、无噪声、暂停无爆音、seek 后 ≤1 个水位时间出新位置声音；
4. **DoP 最高倍率**（受设备 PCM 上限约束）；
5. **Native**（若描述符 raw=true 或 quirk 已配）：同 3 的验收标准，另加：与 DoP 对比听感应一致；
6. **连续切歌 10 次 + 反复 seek**：指示灯全程不变色、无咔嗒；
7. **拔插设备**：正确回退系统输出、重插能恢复独占。
8. **硬件音量（若启用）**：从低响度开始，左右声道同步；0/25/50/100% 写入与读回一致；切换数字/原始模式能恢复 0 dB；DoP/Native 无码流修改且 DAC 模拟响度确实变化。

全部通过后：生成诊断报告存档 + 把验证过的 quirk 条目（若有）回传合入 `assets/usb_dac_quirks.json`。远程设备先导入单条 override 验证，再合入对应厂商目录发包；不要根据厂商名直接推送未知规则。

---

## 7. AI 快速适配协议

> 你是拿到「本指南 + 用户诊断报告（+ 可选 logcat）+ 症状描述」的 AI。目标：输出一条 quirk JSON 让用户导入，或判定需要代码改动并给出精确位置。按以下步骤执行，不要跳步。

### 输入模板（缺项必须显式指出）

将用户材料先整理成下面的输入合同；没有证据的字段写“缺失”，不能自行补全：

```text
Device fingerprint:
  VID/PID/bcdDevice:
  manufacturer/product/serial:
Raw descriptors:
  configuration/interface/endpoint hex:
  AudioControl/AudioStreaming/HID report descriptor:
Vendor app writes:
  status: supplied/missing/not applicable (reason)
  requestType/request/value/index/length/timeout/data or endpoint/packet:
  response/readback and actual loudness:
DAC external controls:
  status: supplied/missing/not applicable (reason)
  button/knob/mute action:
  raw unsolicited packets with timestamps:
Current quirk:
  matched entry/effective fields/load errors:
Failure evidence:
  playback state/message/fallbackReason:
  diagnostic report and relevant English log lines:
```

最低证据按目标能力决定，不强制每台设备都存在厂商 App 或外置按钮：

- **所有适配**：至少提供 VID/PID/`bcdDevice`/product、与目标能力相关的原始描述符、当前 quirk，以及失败状态或完整诊断报告。
- **标准 UAC 硬件音量**：Feature Unit 描述符、规范定义的安全 GET/RANGE、原样 SET 后 readback 和实际响度即可形成闭环；不要求厂商 App 日志。
- **隐藏 UAC、HID、Bulk 或 vendor control**：必须提供厂商实现、抓包或等价可信来源的完整传输证据。没有证据时只能请求材料并回退，不能猜写。
- **主动双向同步**：只有设备客观存在外置按钮/旋钮/mute 或 unsolicited endpoint 时，才要求相应事件日志。设备没有这些控制时写 `not applicable/不适用` 并说明原因。
- **PCM/DSD 传输问题**：与硬件音量无关的厂商写入和外置按钮日志可写 `not applicable/不适用`，原因是本次目标能力不涉及音量协议。

`not applicable/不适用` 只表示设备或目标能力客观不存在该证据来源，必须附原因；尚未抓取、用户未提供、是否存在未知都属于 `missing/缺失`，必须明确请求，不能用“不适用”掩盖证据缺口。

### 输出模板（每次适配都必须包含）

```text
Protocol hypothesis:
  type and packet/control semantics:
  confidence: high/medium/low
  evidence:
Missing evidence:
  ...
Minimal implementation:
  code files/functions to change:
  protocol capabilities and safe failure behavior:
Minimal quirk:
  exact VID/PID match and only evidence-backed fields:
Verification:
  automated tests:
  on-device matrix:
Safe fallback:
  behavior on probe/read/write/event failure:
```

协议假设必须同时给出置信度和逐条证据；输出还必须列出缺失证据、最小代码文件、最小精确 quirk、自动测试、真机测试和失败安全回退。**未知协议不得猜写任何控制命令或寄存器。** 证据不足时，正确输出是请求缺失日志并保持数字音量/本地系统音量回退，而不是生成“试试看”的 vendor 报文。

**步骤 0 —— 提取设备指纹**：从报告 Device 节取 VID/PID/`bcdDevice`/product。后续所有 quirk 先用精确 VID/PID 匹配；指纹只用于定位证据，不得作为协议推断依据。

**步骤 1 —— 判断问题层级**（按症状关键词匹配 §5 表）：
- 报告 Quirk 节有 `Load errors` → 先修用户导入的 JSON 语法，结束。
- "扫描不到/进不了曲库" → 权限/来源问题（§5 末两行），与 quirk 无关。
- "回退到系统输出 + message 有原因" → 读 message 原因，进步骤 2。
- "有声但不对（噪声/咔嗒/爆音）" → 进步骤 3。

**步骤 2 —— 回退原因 → 对策映射**：
| message 关键词 | 输出 |
| --- | --- |
| `not supporting DoP (quirk` | 用户/内置 quirk 已标不支持；如用户确认设备实际支持，发 `dop.supported:true` 覆盖 |
| `exceeds this device's DoP limit` / `native DSD limit` | 提高或删除对应 maxDsd（先确认设备规格书真支持） |
| `DoP requires a 24/32-bit output slot` | 设备 16-bit-only，DoP 物理不可能；建议 PCM 模式 |
| `no RAW_DATA alt and no nativeDsd quirk` | 查设备规格书是否支持 native；支持则发 `nativeDsd.format`（XMOS/Amanero 系默认 `u32le`） |
| `no fitting alt for native DSD` | 对照 Output candidates：有无 subslot 与格式同宽且 maxPacket 够的 alt；无则限 maxDsd 或改用 DoP |
| `DAC 未接受采样率…读回 X Hz` | X 是垃圾值 → `clock.skipGetCurValidation:true`；X 是别的合法率 → 设备真不支持该率，检查源/固定采样率设置 |

硬件音量回退看 `Exclusive session → hardwareVolume`：

- `No unique writable playback Feature Unit passed probing`：先看 `Hardware volume probe`。只有一个正确播放 Feature Unit 时，用报告里的 `controlInterface`、`featureUnitId` 和声道生成单字段 `hardwareVolume` quirk。
- `Failed to claim/read/set` 或 `readback mismatch`：不要猜声道；先用低音量重试并回传新报告。确认设备硬件音量不可写时输出 `hardwareVolume.enabled:false`。
- PCM 可调但 DoP/Native DSD 实际音量不变：输出 `hardwareVolume.dsdSupported:false`，不得在 DSD 数据路径增加软件增益。
- 描述符没有 Feature Unit，但厂商 App 可调：按 §4.1 搜厂商 APK。若是两字节 Q8.8 UAC 隐藏实体，必须取得 `recipient/unit/interface/channels/range/mute` 全套证据；缺一项就先请求日志或只读探测，不输出猜测 quirk。
- 日志 `hardware volume SET_CUR ... recipient=device, source=quirk` 且读回匹配，但实际响度不变：协议可能只控制软件端点或 DSD 路径旁路；PCM/DSD 分开验证，必要时分别设置 `enabled:false` 或 `dsdSupported:false`。
- 验证顺序固定为 PCM 低音量 → 物理键/拖动 → 暂停切歌 → DoP/Native；通过后把同一条 VID/PID 配置合入内置统一表。

**步骤 3 —— 声音异常诊断**（需要 logcat）：
1. 取 `USB feedback actual … approxFrames=F` 与名义值 `N = 请求采样率 ÷ packetsPerSecond`（都在日志里）。
   - `F ≈ N`（±5%）→ 时钟正常，进 3.2；
   - `F ≈ k×N`（k=2/4/…）或完全无关 → 时钟未被接受：核对 SET_CUR 值是否符合铁律 3；DAC 需要锁定时间 → `clock.setCurDelayMs:50`；仍不行报告代码问题（`configureUsbAudioClock`）。
2. 时钟正常但噪声：
   - DoP 全幅噪声 → `dop.supported:false`（或降 maxDsd）；
   - native 噪声 → 依次试 `nativeDsd.format`: 当前值→`u32be`→`u16le`；每次只改一个变量，让用户**音量调低**验证（native 无 DoP 标记保护，排列错误直接全幅噪声）；
   - 周期性小咔嗒 → 让用户做暂停二分（§5 papapa 行），把结果带回来再判。
3. 切歌/seek 咔嗒 + 指示灯变色 → 检查是否新代码在 DSD 会话调用了 `flushOutput`（铁律 1），这不是 quirk 能解决的，指向 `UsbExclusiveAudioEngine` 的 stop/seek/热复用路径。

**步骤 4 —— 输出**。按上面的输出模板先给协议假设、证据与缺失证据。quirk 修改输出完整可粘贴 JSON（含 version/devices 包裹、精确 match 指纹、label 写设备名），并附一句“导入后重新连接设备生效；如无效把新的诊断报告+日志发回”。代码问题则给出最小文件+函数名+违反的铁律编号、协议能力声明和测试矩阵；任何失败都必须说明如何回退到数字音量或本地系统音量。

**禁止事项**：不要建议在 DoP/native 数据路径加软件音量/DSP/重采样（Feature Unit 硬件音量不修改码流）；不要建议 seek/切歌时 flush（铁律 1）；不要把 GET_CUR=0 当失败（已内置豁免）；不要一次改多个 quirk 字段（无法归因）；不要从 VID、厂商名或相邻型号复制未知私有协议；不要在缺少 readback/实际响度证据时宣称硬件音量已验证。

### quirk 试验模板（按需删改）

```json
{"version":1,"devices":[{"match":{"vid":"0x____","pid":"0x____","label":"____"},"dop":{"supported":true,"maxDsd":256},"nativeDsd":{"format":"u32le","maxDsd":256},"clock":{"setCurDelayMs":0,"skipGetCurValidation":false}}]}
```

硬件音量候选不唯一或描述符漏报时：

```json
{"version":1,"devices":[{"match":{"vid":"0x____","pid":"0x____","label":"____"},"hardwareVolume":{"enabled":true,"featureUnitId":7,"controlInterface":0,"channels":[0],"recipient":"interface"}}]}
```

隐藏 Feature Unit 且 RANGE 不可读时（数值必须来自厂商实现或真机证据）：

```json
{"version":1,"devices":[{"match":{"vid":"0x____","pid":"0x____","label":"____"},"hardwareVolume":{"enabled":true,"featureUnitId":10,"controlInterface":1,"channels":[1,2],"protocol":"uac2","recipient":"device","range":{"minDb":-63,"maxDb":0,"stepDb":1,"muteDb":-112}}}]}
```
