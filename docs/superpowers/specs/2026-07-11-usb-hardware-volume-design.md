# USB 独占硬件音量安全自动适配设计

## 目标

在现有 USB 独占链路中接通 UAC1/UAC2 Feature Unit 硬件音量，保持 PCM、DoP 和 Native DSD 数据路径不变。标准且可安全验证的设备自动使用硬件音量；描述符异常或存在多个候选的设备通过现有 DAC quirk 指定；任何探测、写入或回读异常都立即回退 PCM 数字音量，DSD 保持原始码流且不伪装可调。

## 范围

- 复用 `UsbExclusiveAudioEngine`、`UsbDacQuirks`、`UsbAudioService` 和现有音量偏好，不新增 bridge、publisher 或单用途管理类。
- 不改变独占音量浮层的布局、动画和触控手感。
- 不修改 `BackdropFilter`、`CoverArtWidget`、歌词页或横屏背景。
- 统一设备规则继续保存在 `android/app/src/main/assets/usb_dac_quirks.json`，本地导入 override 继续用于真机验证。

## 自动选择

1. 从原始描述符解析 UAC1/UAC2 Feature Unit 的协议、控制接口、Unit ID、声道和可写状态，并通过 AS `bTerminalLink` 与 AC Entity 的 Source ID 关系确认它位于当前播放输出路径，排除录音和无关音频功能。
2. quirk 同时给出 `featureUnitId` 与 `controlInterface` 时优先使用该候选；`channels` 非空时只控制指定声道。
3. 无 quirk 时，只接受唯一、可写且探测成功的播放候选：优先主声道 0；没有主声道时使用同一 Feature Unit 中全部可写逻辑声道。
4. 候选不唯一、范围非法、当前值读取失败或无法确认可写时，不自动写入。
5. 描述符漏报但 quirk 完整指定时，按 quirk 合成候选并通过真实 GET/RANGE 探测确认，不能仅凭配置直接写入。

## 音量映射与写入

- Flutter 继续传递 0..1 的用户音量和 `auto/dac/digital/raw` 模式；Android 原生层决定实际使用硬件还是数字音量。
- 硬件音量按设备报告的 Q8.8 dB 范围映射，并按分辨率吸附；0 映射为静音值，1 不超过设备报告的最大值。
- 首次启用硬件音量时先读取当前值，再以当前用户音量为目标写入，避免先写满刻度。
- 多声道写入前保存各声道当前值；任一写入或回读失败时恢复已修改声道，防止左右声道失衡。
- 每次 SET_CUR 后 GET_CUR 回读；设备允许按分辨率取整，回读值落在目标步进容差内才算成功。
- 控制传输在引擎内串行执行，不能与设备释放并发使用已关闭连接。

## 模式与回退

- `auto`：硬件候选安全可用时使用硬件音量；否则 PCM 使用现有数字音量，DSD 保持原始码流且不接管无效音量键。
- `dac`：尝试硬件音量；失败后的运行行为与 `auto` 一致，并在诊断状态中记录原因。
- `digital`：保持现有 PCM 数字音量；DSD 继续旁路。
- `raw`：PCM、DoP、Native DSD 全部保持原始电平，不接管物理音量键。
- 硬件音量可用于 DoP/Native DSD 的前提是 Feature Unit 写入和回读成功；它不修改 DSD 数据。若 DAC 的 DSD 路径忽略该控制，需通过真机验证后在 quirk 中禁用 DSD 硬件音量。

## quirk 与统一目录

保留现有字段：

```json
"hardwareVolume": {
  "featureUnitId": 7,
  "controlInterface": 0,
  "channels": [0, 1, 2]
}
```

补充最小必要字段：

- `enabled: false`：设备声明了 Feature Unit 但写入不安全或不起作用时禁用硬件音量。
- `dsdSupported: false`：PCM 硬件音量正常，但 DoP/Native DSD 路径不响应时仅对 DSD 禁用。

诊断报告输出自动选择结果、实际范围、当前值、SET/GET 结果、回退原因和可直接粘贴的 quirk 建议。验证通过的 VID/PID 条目按现有 version 2 厂商分组格式合入统一 JSON。

## 测试与验收

- Kotlin 纯逻辑测试覆盖：UAC1/UAC2 Feature Unit 解析、quirk 优先级、唯一候选选择、范围映射、步进吸附、回读容差、多声道失败回滚判定。
- Dart 测试覆盖：四种控制模式的通道参数与状态解析，不增加与中文文案或私有 Widget 结构耦合的测试。
- Flutter 3.44 执行 `gen-l10n`、相关测试和 `analyze`。
- 真机按低音量起步验证 PCM，再验证 DoP/Native DSD；覆盖物理音量键、滑动调节、切歌、暂停恢复、拔插和失败回退。
- 提交前排除所有无关 generated 文件、临时诊断文件和非 USB 视觉改动。
