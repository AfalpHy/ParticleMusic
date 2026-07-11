package com.afalphy.sylvakru

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

// 只测纯解析与匹配逻辑（parseEntries/matchQuirk），asset/override 的文件装载依赖 Android 运行时
class UsbDacQuirksTest {
    private val sample = """
        {
          "version": 1,
          "devices": [
            {
              "match": { "vid": "0x20b1", "pid": "0x0002", "label": "XMOS XU208" },
              "dop": { "supported": true, "maxDsd": 256 },
              "nativeDsd": { "format": "u32le", "maxDsd": 512 },
              "clock": { "setCurDelayMs": 50, "skipGetCurValidation": true },
              "flags": ["keep-alt-on-pause"]
            },
            {
              "match": { "vid": "0x262a", "pid": "*", "label": "SAVITECH vendor default" },
              "dop": { "supported": false }
            }
          ]
        }
    """.trimIndent()

    @Test
    fun parsesFieldsAndNormalizesIds() {
        val entries = UsbDacQuirks.parseEntries(sample)
        assertEquals(2, entries.size)
        assertEquals("0x20b1:0x0002", entries[0].first)
        val quirk = entries[0].second
        assertEquals("XMOS XU208", quirk.label)
        assertEquals(true, quirk.dopSupported)
        assertEquals(256, quirk.dopMaxDsd)
        assertEquals("u32le", quirk.nativeDsdFormat)
        assertEquals(512, quirk.nativeDsdMaxDsd)
        assertEquals(50, quirk.clockSetCurDelayMs)
        assertTrue(quirk.clockSkipGetCurValidation)
        assertEquals(listOf("keep-alt-on-pause"), quirk.flags)
        assertEquals("0x262a:*", entries[1].first)
    }

    @Test
    fun exactMatchBeatsVendorWildcard() {
        val entries = UsbDacQuirks.parseEntries(sample)
        val exact = UsbDacQuirks.matchQuirk(entries, 0x20b1, 0x0002)
        assertEquals("XMOS XU208", exact?.label)
        // 厂商通配：同 vid 不同 pid
        val vendor = UsbDacQuirks.matchQuirk(entries, 0x262a, 0x9999)
        assertEquals(false, vendor?.dopSupported)
        // 未命中
        assertNull(UsbDacQuirks.matchQuirk(entries, 0x1234, 0x5678))
    }

    @Test
    fun overrideEntryWinsWhenListedFirst() {
        val override = UsbDacQuirks.parseEntries(
            """{"version":1,"devices":[{"match":{"vid":"0x20b1","pid":"0x0002"},"dop":{"supported":false}}]}""",
        )
        val merged = override + UsbDacQuirks.parseEntries(sample)
        assertEquals(false, UsbDacQuirks.matchQuirk(merged, 0x20b1, 0x0002)?.dopSupported)
    }

    @Test
    fun missingSectionsFallBackToDefaults() {
        val entries = UsbDacQuirks.parseEntries(
            """{"version":1,"devices":[{"match":{"vid":"20b1","pid":"0002"}}]}""",
        )
        assertEquals("0x20b1:0x0002", entries[0].first)
        val quirk = entries[0].second
        assertNull(quirk.dopSupported)
        assertNull(quirk.dopMaxDsd)
        assertNull(quirk.nativeDsdFormat)
        assertEquals(0, quirk.clockSetCurDelayMs)
        assertEquals(false, quirk.clockSkipGetCurValidation)
        assertTrue(quirk.flags.isEmpty())
    }

    @Test
    fun invalidEntriesAreSkippedNotFatal() {
        val entries = UsbDacQuirks.parseEntries(
            """{"version":1,"devices":[{"match":{"vid":"not-hex","pid":"0x1"}},{"nope":true},
               {"match":{"vid":"0x1","pid":"0x2"}}]}""",
        )
        assertEquals(1, entries.size)
        assertEquals("0x0001:0x0002", entries[0].first)
    }

    @Test
    fun parsesVendorCatalogWithHardwareVolumeOverride() {
        val entries = UsbDacQuirks.parseEntries(
            """
                {
                  "version": 2,
                  "vendors": [
                    {
                      "match": { "vid": "0x20b1", "label": "XMOS" },
                      "devices": [
                        {
                          "match": { "pid": "0x0002", "label": "XU208 DAC" },
                          "hardwareVolume": {
                            "enabled": false,
                            "dsdSupported": false,
                            "featureUnitId": 7,
                            "controlInterface": 0,
                            "channels": [0, 1, 2],
                            "recipient": "device",
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
                          "clock": { "setCurDelayMs": 40 }
                        }
                      ]
                    }
                  ]
                }
            """.trimIndent(),
        )

        val exact = UsbDacQuirks.matchQuirk(entries, 0x20b1, 0x0002)
        assertEquals("XU208 DAC", exact?.label)
        assertEquals(7, exact?.hardwareVolumeFeatureUnitId)
        assertEquals(0, exact?.hardwareVolumeControlInterface)
        assertEquals(listOf(0, 1, 2), exact?.hardwareVolumeChannels)
        assertEquals("device", exact?.hardwareVolumeRecipient)
        assertEquals(-63 * 256, exact?.hardwareVolumeMinQ8_8)
        assertEquals(0, exact?.hardwareVolumeMaxQ8_8)
        assertEquals(256, exact?.hardwareVolumeStepQ8_8)
        assertEquals(-112 * 256, exact?.hardwareVolumeMuteQ8_8)
        assertEquals(false, exact?.hardwareVolumeEnabled)
        assertEquals(false, exact?.hardwareVolumeDsdSupported)

        val vendor = UsbDacQuirks.matchQuirk(entries, 0x20b1, 0x9999)
        assertEquals("XMOS", vendor?.label)
        assertEquals(40, vendor?.clockSetCurDelayMs)
    }
}
