# Android 手柄插件启动崩溃修复设计

## 问题

`flutter_gamepads` 引入的 `gamepads_android` 会在插件绑定 Activity 时，将当前 Activity 转换为 `GamepadsCompatibleActivity`。项目的 `MainActivity` 继承 `AudioServiceActivity`，但没有实现该接口，因此 Android 启动阶段抛出 `ClassCastException`，应用进程退出，Flutter 随后报告无法连接 Dart VM Service。

## 方案比较

1. **让现有 `MainActivity` 实现插件接口（采用）**：保留音频服务和 USB 逻辑，只增加插件要求的监听器注册与输入事件转发，改动最小且保留手柄功能。
2. 移除 `flutter_gamepads`：可以避免插件注册，但会删除刚加入的外接媒体按键能力，不符合当前功能目标。
3. 修改或派生 `gamepads_android`：能够改变插件的强制转换行为，但需要维护第三方分支，范围和维护成本都更大。

## 实现设计

在现有 `MainActivity : AudioServiceActivity()` 后实现 `GamepadsCompatibleActivity`，保存插件注册的按键和摇杆事件处理器，并通过 Activity 的输入事件入口将事件转发给插件。输入设备监听直接使用 Android `InputManager` 注册。

现有 USB、歌词、音频服务和媒体按键处理逻辑保持不变；只有插件确认已处理事件时才提前返回，否则继续调用父类实现。

## 验证

1. 先添加 Android JVM 回归测试，断言 `MainActivity` 满足 `GamepadsCompatibleActivity` 契约，并确认修改前测试失败。
2. 完成最小实现后重新运行该测试及 Android JVM 测试。
3. 运行 Kotlin 编译、Flutter analyze，并在已连接设备上以 profile 模式启动，确认不再出现 Activity 类型转换崩溃且 Dart VM Service 能连接。

## 范围

只修改 Android `MainActivity`、对应回归测试及本设计说明。不修改 USB 播放实现、界面、歌词页或其他平台逻辑。
