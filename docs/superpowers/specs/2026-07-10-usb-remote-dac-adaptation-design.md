# USB 远程 DAC 适配设计

## 目标

让无法直接连接到开发机的 USB DAC，通过一次问题复现后的诊断报告完成远程判定、quirk 验证和后续内置发版；同时将内置适配规则按厂商分组维护。

## 配置目录

内置 `android/app/src/main/assets/usb_dac_quirks.json` 使用版本 2 的 `vendors` 数组。每个厂商使用 `match.vid` 标识，厂商下的每个设备只填写 `match.pid` 和设备级 quirk。`pid: "*"` 表示该厂商的默认规则。

解析器继续支持版本 1 的平铺 `devices` 数组，因此已导入的本地 override 和既有适配指南中的 JSON 都不需要迁移。加载顺序不变：override 在内置目录之前，先命中者优先。

## 远程诊断包

诊断报告升级为 v2，并加入一次独占会话的事实快照：

- 会话 ID 与输入请求（不记录完整文件路径）；
- 每次 alt 选择的请求条件、候选能力、所需包大小和最终选择；
- UAC1/UAC2 时钟请求、SET_CUR 结果、GET_CUR 读回与 quirk 相关开关；
- 反馈端点最后观测值、名义值与忽略计数；
- 提交字节数、ISO 包数、待处理 URB、欠载数和缓冲水位。

报告只记录现有播放过程产生的事实，不据此自动应用未知 quirk。远程流程保持为：报告判定 -> 导入单条 override 验证 -> 验证通过后合入厂商目录 -> 随版本发布。

## 硬件音量适配准备

当前“DAC 硬件音量”仍回退为数字音量。本次不改变它的播放行为，而是把后续适配所需的标准 Feature Unit 数据纳入报告和 quirk 目录。

报告需要采集 AudioControl 接口号、UAC 协议版本、Feature Unit ID、各声道的 Volume Control 可读/可写状态、当前值与范围探测结果。音量值统一保存为有符号 `q8_8Db`，即 1/256 dB。quirk 可选指定 `featureUnitId`、`controlInterface` 与 `channels`，仅用于修正设备描述符遗漏或厂商实现差异。

后续实现写入时，先对标准声明为可写的主声道 `0` 执行 CUR/范围读回验证，再允许用户显式选用硬件音量。无法读回、范围异常或未验证的设备保持数字音量回退，绝不根据单纯厂商名盲写。

## 验收

1. 厂商分组 JSON 能解析出设备级和厂商通配规则，旧版 JSON 仍能解析。
2. 生成报告时包含独占会话数据；没有会话时明确显示无可用快照。
3. 报告包含硬件音量 Feature Unit 探测与 quirk 覆盖参数；当前 UI 继续回退数字音量。
4. Dart 单元测试和 Android JVM 单元测试覆盖新增格式及报告文本。
5. Flutter analyze、相关 Flutter 测试和 Android JVM 测试通过。
