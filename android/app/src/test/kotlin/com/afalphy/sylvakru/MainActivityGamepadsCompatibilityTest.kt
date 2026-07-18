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
