# Android 手柄插件启动崩溃修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 Android `MainActivity` 满足 `gamepads_android` 的 Activity 契约，消除应用启动时的类型转换崩溃。

**Architecture:** 保留现有 `AudioServiceActivity` 继承关系，在同一个 `MainActivity` 上实现 `GamepadsCompatibleActivity`。插件注册的按键和摇杆处理器由 Activity 保存，现有 USB 音量键逻辑优先处理，未处理的事件再交给手柄插件或父类。

**Tech Stack:** Kotlin、Flutter Android embedding、`gamepads_android`、JUnit 4、Gradle

---

### Task 1: 用回归测试固定 Activity 契约

**Files:**
- Create: `android/app/src/test/kotlin/com/afalphy/sylvakru/MainActivityGamepadsCompatibilityTest.kt`

- [ ] **Step 1: 写入失败测试**

```kotlin
package com.afalphy.sylvakru

import org.flame_engine.gamepads_android.GamepadsCompatibleActivity
import org.junit.Assert.assertTrue
import org.junit.Test

class MainActivityGamepadsCompatibilityTest {
    @Test
    fun implementsGamepadsCompatibleActivityContract() {
        assertTrue(
            GamepadsCompatibleActivity::class.java.isAssignableFrom(MainActivity::class.java),
        )
    }
}
```

- [ ] **Step 2: 运行测试并确认因契约缺失而失败**

Run: `cd android; .\gradlew.bat app:testProfileUnitTest --tests com.afalphy.sylvakru.MainActivityGamepadsCompatibilityTest`

Expected: FAIL，断言显示 `MainActivity` 不是 `GamepadsCompatibleActivity`。

### Task 2: 最小实现手柄插件 Activity 契约

**Files:**
- Modify: `android/app/src/main/kotlin/com/afalphy/sylvakru/MainActivity.kt`
- Test: `android/app/src/test/kotlin/com/afalphy/sylvakru/MainActivityGamepadsCompatibilityTest.kt`

- [ ] **Step 1: 实现接口和事件处理器注册**

增加 `InputManager`、`InputDevice`、`MotionEvent` 和 `GamepadsCompatibleActivity` 导入；将类声明改为：

```kotlin
class MainActivity : AudioServiceActivity(), GamepadsCompatibleActivity {
```

保存插件回调：

```kotlin
private var gamepadsKeyEventHandler: ((KeyEvent) -> Boolean)? = null
private var gamepadsMotionEventHandler: ((MotionEvent) -> Boolean)? = null
```

实现注册方法：

```kotlin
override fun registerInputDeviceListener(
    listener: InputManager.InputDeviceListener,
    handler: Handler?,
) {
    val inputManager = getSystemService(Context.INPUT_SERVICE) as InputManager
    inputManager.registerInputDeviceListener(listener, handler)
}

override fun registerKeyEventHandler(handler: (KeyEvent) -> Boolean) {
    gamepadsKeyEventHandler = handler
}

override fun registerMotionEventHandler(handler: (MotionEvent) -> Boolean) {
    gamepadsMotionEventHandler = handler
}
```

- [ ] **Step 2: 转发未被 USB 音量逻辑消费的输入事件**

在现有 `dispatchKeyEvent` 的 USB 分支之后、调用父类之前加入：

```kotlin
if (gamepadsKeyEventHandler?.invoke(event) == true) {
    return true
}
```

增加摇杆事件入口：

```kotlin
override fun dispatchGenericMotionEvent(event: MotionEvent): Boolean {
    if (gamepadsMotionEventHandler?.invoke(event) == true) {
        return true
    }
    return super.dispatchGenericMotionEvent(event)
}
```

- [ ] **Step 3: 运行目标测试并确认通过**

Run: `cd android; .\gradlew.bat app:testProfileUnitTest --tests com.afalphy.sylvakru.MainActivityGamepadsCompatibilityTest`

Expected: PASS。

- [ ] **Step 4: 提交修复**

```bash
git add android/app/src/main/kotlin/com/afalphy/sylvakru/MainActivity.kt android/app/src/test/kotlin/com/afalphy/sylvakru/MainActivityGamepadsCompatibilityTest.kt
git commit -m "fix(android): 修复手柄插件启动崩溃"
```

### Task 3: 完整验证

**Files:**
- Verify: `android/app/src/main/kotlin/com/afalphy/sylvakru/MainActivity.kt`

- [ ] **Step 1: 运行 Android JVM 测试**

Run: `cd android; .\gradlew.bat app:testDebugUnitTest app:testProfileUnitTest`

Expected: BUILD SUCCESSFUL，全部测试通过。

- [ ] **Step 2: 运行 Flutter 静态分析**

Run: `F:\software\flutter_3.44.5\bin\flutter.bat analyze`

Expected: `No issues found!`。

- [ ] **Step 3: 运行 profile 真机启动验证**

Run: `F:\software\flutter_3.44.5\bin\flutter.bat run --profile -d e92f5c16 --no-resident`

Expected: 应用成功启动，日志中不再出现 `MainActivity cannot be cast to GamepadsCompatibleActivity`，命令正常退出。

- [ ] **Step 4: 检查最终提交与工作区**

Run: `git status --short; git log -2 --oneline`

Expected: 只有先前已经存在且未纳入本次修复的 generated registrant 变动；最新提交为 Android 启动修复。
