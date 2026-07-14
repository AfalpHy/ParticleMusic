# USB PCM 自动位深设计

## 目标

让“PCM 位深：自动”按当前歌曲的源 PCM 位深选择 DAC 输出端点，而不是固定优先 24-bit；同时修正 USB 设置页把 DAC 槽位位深误写成源文件位深的问题。

## 现状与根因

Flutter 在自动模式下向原生层传入空位深。原生 `findOutputTarget` 收到空值后固定按 `24、32、16` 查找端点，因此 16-bit 歌曲也会优先使用 24-bit USB 槽位。

USB 设置页“源文件”行调用 `_compactDepthLabel`。独占播放激活时，该函数返回输出端点位深，导致 16-bit 源文件被显示为 24-bit。播放详情面板已经分别保存 `sourceBitDepth`、`decodedBitDepth` 与 `usbBitDepth`，三者语义不应合并。

## 方案

1. 固定 16/24/32 模式保持现有行为。
2. PCM 自动模式在选择 USB alternate setting 前，用 `MediaExtractor` 读取当前音轨的 `bits-per-sample`。读取失败或格式未声明时继续使用现有兼容回退，不阻止播放。
3. 自动端点选择优先精确匹配源位深；没有精确匹配时，选择能容纳源位深的最小更宽槽位；仍无匹配时才使用现有候选排序。
4. DSD Native/DoP 的位深选择逻辑不变。
5. USB 设置页“源文件”位深只显示独占状态中的 `sourceBitDepth`。尚未解析到真实源位深时显示“未知”，不再使用 DAC 端点或用户偏好值代替。
6. 输出编码继续显示解码有效位深；USB 槽位单独显示端点位深。位深扩展不增加有效精度。

## 数据流

当前歌曲路径 → 原生预读音轨格式 → 得到可选源位深 → `findOutputTarget` 按源位深选端点 → 解码器报告实际有效位深 → 状态分别发布源位深、解码有效位深和 USB 槽位。

## 失败处理

流式缓存尚不足、容器未声明位深或 `MediaExtractor` 无法读取时，记录英文诊断日志并退回现有自动候选逻辑。预读失败不应中断播放，也不应影响 DSD。

## 验证

- Kotlin 单元测试覆盖 16-bit 精确匹配、无精确匹配时选择最小更宽槽位、未知源位深兼容回退，以及固定模式不受影响。
- Dart 单元测试覆盖设置页源位深标签优先使用 `sourceBitDepth`，未知时不冒用 USB 槽位。
- 运行 Flutter 全量测试、Flutter analyze、Android 原生单元测试，并构建 arm64 Profile APK。
