package com.afalphy.sylvakru

import android.content.Context
import java.io.File
import kotlin.math.roundToInt
import org.json.JSONArray
import org.json.JSONObject

/**
 * 单台（或单厂商）DAC 的 quirk 生效值。所有字段可缺省，缺省即默认行为。
 * 承载"USB 描述符探测不到"的设备差异：DoP 是否支持、native DSD 字节排列、时钟锁定延时等
 * （与 Linux snd-usb-audio 的 VID/PID quirk 表解决同类问题）。
 */
data class DacQuirk(
    val label: String? = null,
    // null=未知：按硬性条件（24/32-bit alt + 帧率可用）尝试；true/false=quirk 明确判定
    val dopSupported: Boolean? = null,
    val dopMaxDsd: Int? = null,
    // u8 / u16le / u32le / u32be，null=设备未声明 native DSD 排列
    val nativeDsdFormat: String? = null,
    val nativeDsdMaxDsd: Int? = null,
    // 部分 DAC SET_CUR 后需要几十 ms 锁定新时钟，立刻开流会爆音
    val clockSetCurDelayMs: Int = 0,
    // 个别设备 GET_CUR 返回垃圾但 SET_CUR 实际生效
    val clockSkipGetCurValidation: Boolean = false,
    // 标准 Feature Unit 或厂商协议的硬件音量覆盖。
    val hardwareVolumeFeatureUnitId: Int? = null,
    val hardwareVolumeControlInterface: Int? = null,
    val hardwareVolumeChannels: List<Int> = emptyList(),
    val hardwareVolumeProtocol: String? = null,
    val hardwareVolumeRecipient: String = "interface",
    val hardwareVolumeMinQ8_8: Int? = null,
    val hardwareVolumeMaxQ8_8: Int? = null,
    val hardwareVolumeStepQ8_8: Int? = null,
    val hardwareVolumeMuteQ8_8: Int? = null,
    val hardwareVolumeEnabled: Boolean? = null,
    val hardwareVolumeDsdSupported: Boolean? = null,
    val flags: List<String> = emptyList(),
)

/**
 * quirk 配置加载与匹配：内置 asset + 本地 override 合并（override 优先），
 * 按 `vid:pid` 精确匹配 → `vid:*` 厂商匹配 → 内置默认值三级查找。
 *
 * override 文件（appSupportDir/usb_dac_quirks_override.json）支撑"验证不发版"闭环：
 * 开发者从诊断报告起草单条 quirk JSON → 用户导入 → 重连验证 → 通过后合入 asset 随版发布。
 * "记住此设备支持 DoP"的用户确认结果也写进同一个 override 文件。
 */
object UsbDacQuirks {
    private const val ASSET_NAME = "usb_dac_quirks.json"
    const val OVERRIDE_FILE_NAME = "usb_dac_quirks_override.json"

    private val lock = Any()
    private var loaded = false
    // override 条目在前，同 key 时先命中
    private var entries: List<Pair<String, DacQuirk>> = emptyList()
    private var assetError: String? = null
    private var overrideError: String? = null

    fun forDevice(context: Context, vendorId: Int, productId: Int): DacQuirk {
        ensureLoaded(context)
        return matchQuirk(entries, vendorId, productId) ?: DacQuirk()
    }

    /** 诊断报告用：命中条目的描述（"vid:pid label" / "vid:* label" / null=默认值）。 */
    fun matchDescription(context: Context, vendorId: Int, productId: Int): String? {
        ensureLoaded(context)
        val exactKey = matchKey(vendorId, productId)
        val vendorKey = matchKey(vendorId, null)
        val hit = entries.firstOrNull { it.first == exactKey }
            ?: entries.firstOrNull { it.first == vendorKey }
            ?: return null
        return "${hit.first}${hit.second.label?.let { " ($it)" } ?: ""}"
    }

    /** 诊断报告用：配置加载错误（JSON 解析失败不崩溃，只在报告里注明）。 */
    fun loadErrors(context: Context): List<String> {
        ensureLoaded(context)
        return listOfNotNull(
            assetError?.let { "asset: $it" },
            overrideError?.let { "override: $it" },
        )
    }

    /** 导入 quirk 配置：整体写入 override 文件（先校验可解析），返回错误串或 null。 */
    fun importOverride(context: Context, json: String): String? {
        try {
            parseEntries(json)
        } catch (error: Exception) {
            return "Invalid quirk JSON: ${error.message}"
        }
        return try {
            overrideFile(context).writeText(json)
            invalidate()
            null
        } catch (error: Exception) {
            "Failed to write override file: ${error.message}"
        }
    }

    /**
     * 用户确认"此设备 DoP 正常"后持久化到 override：追加（或替换）一条
     * `{"match":{vid,pid,label},"dop":{"supported":true}}`，与手动导入共用加载逻辑。
     */
    fun rememberDopSupported(
        context: Context,
        vendorId: Int,
        productId: Int,
        label: String?,
    ): String? {
        return try {
            val file = overrideFile(context)
            val root = if (file.exists()) {
                try {
                    JSONObject(file.readText())
                } catch (_: Exception) {
                    JSONObject()
                }
            } else {
                JSONObject()
            }
            if (!root.has("version")) {
                root.put("version", 1)
            }
            val devices = root.optJSONArray("devices") ?: JSONArray().also {
                root.put("devices", it)
            }
            val vid = hex(vendorId)
            val pid = hex(productId)
            var entry: JSONObject? = null
            for (index in 0 until devices.length()) {
                val device = devices.optJSONObject(index) ?: continue
                val match = device.optJSONObject("match") ?: continue
                if (match.optString("vid") == vid && match.optString("pid") == pid) {
                    entry = device
                    break
                }
            }
            if (entry == null) {
                entry = JSONObject().put(
                    "match",
                    JSONObject().put("vid", vid).put("pid", pid).apply {
                        if (!label.isNullOrBlank()) put("label", label)
                    },
                )
                devices.put(entry)
            }
            val dop = entry.optJSONObject("dop") ?: JSONObject().also { entry.put("dop", it) }
            dop.put("supported", true)
            file.writeText(root.toString(2))
            invalidate()
            null
        } catch (error: Exception) {
            "Failed to remember DoP support: ${error.message}"
        }
    }

    private fun ensureLoaded(context: Context) {
        synchronized(lock) {
            if (loaded) {
                return
            }
            val merged = mutableListOf<Pair<String, DacQuirk>>()
            overrideError = null
            assetError = null
            val file = overrideFile(context)
            if (file.exists()) {
                try {
                    merged += parseEntries(file.readText())
                } catch (error: Exception) {
                    overrideError = error.message ?: error.toString()
                }
            }
            try {
                context.assets.open(ASSET_NAME).use { stream ->
                    merged += parseEntries(stream.readBytes().decodeToString())
                }
            } catch (error: Exception) {
                assetError = error.message ?: error.toString()
            }
            entries = merged
            loaded = true
            UsbDiagnostics.i(
                "UsbDacQuirks",
                "quirks loaded entries=${entries.size}, " +
                    "assetError=$assetError, overrideError=$overrideError",
            )
        }
    }

    private fun invalidate() {
        synchronized(lock) { loaded = false }
    }

    private fun overrideFile(context: Context): File = File(context.filesDir, OVERRIDE_FILE_NAME)

    // ---- 纯解析/匹配逻辑（不依赖 Android 运行时，便于 JVM 单测） ----

    fun parseEntries(json: String): List<Pair<String, DacQuirk>> {
        val root = JSONObject(json)
        val result = mutableListOf<Pair<String, DacQuirk>>()
        appendEntries(result, root.optJSONArray("devices"))
        val vendors = root.optJSONArray("vendors")
        if (vendors != null) {
            for (index in 0 until vendors.length()) {
                val vendor = vendors.optJSONObject(index) ?: continue
                val match = vendor.optJSONObject("match") ?: continue
                val vid = normalizeId(match.optString("vid")) ?: continue
                appendEntries(
                    result,
                    vendor.optJSONArray("devices"),
                    vendorVid = vid,
                    vendorLabel = match.optString("label").takeIf { it.isNotEmpty() },
                )
            }
        }
        return result
    }

    private fun appendEntries(
        result: MutableList<Pair<String, DacQuirk>>,
        devices: JSONArray?,
        vendorVid: String? = null,
        vendorLabel: String? = null,
    ) {
        if (devices == null) {
            return
        }
        for (index in 0 until devices.length()) {
            val device = devices.optJSONObject(index) ?: continue
            val match = device.optJSONObject("match") ?: continue
            val vid = vendorVid ?: normalizeId(match.optString("vid")) ?: continue
            val rawPid = match.optString("pid")
            val pid = if (rawPid == "*" || rawPid.isEmpty()) {
                "*"
            } else {
                normalizeId(rawPid) ?: continue
            }
            val dop = device.optJSONObject("dop")
            val nativeDsd = device.optJSONObject("nativeDsd")
            val clock = device.optJSONObject("clock")
            val hardwareVolume = device.optJSONObject("hardwareVolume")
            val hardwareVolumeRange = hardwareVolume?.optJSONObject("range")
            val flagsArray = device.optJSONArray("flags")
            result += "$vid:$pid" to DacQuirk(
                label = match.optString("label").takeIf { it.isNotEmpty() } ?: vendorLabel,
                dopSupported = if (dop?.has("supported") == true) {
                    dop.optBoolean("supported")
                } else {
                    null
                },
                dopMaxDsd = dop?.optInt("maxDsd", 0)?.takeIf { it > 0 },
                nativeDsdFormat = nativeDsd?.optString("format")?.takeIf { it.isNotEmpty() },
                nativeDsdMaxDsd = nativeDsd?.optInt("maxDsd", 0)?.takeIf { it > 0 },
                clockSetCurDelayMs = clock?.optInt("setCurDelayMs", 0) ?: 0,
                clockSkipGetCurValidation = clock?.optBoolean("skipGetCurValidation") == true,
                hardwareVolumeFeatureUnitId = hardwareVolume
                    ?.optInt("featureUnitId", 0)
                    ?.takeIf { it in 1..255 },
                hardwareVolumeControlInterface = hardwareVolume
                    ?.optInt("controlInterface", -1)
                    ?.takeIf { it >= 0 },
                hardwareVolumeChannels = buildList {
                    val channels = hardwareVolume?.optJSONArray("channels") ?: return@buildList
                    for (channelIndex in 0 until channels.length()) {
                        val channel = channels.optInt(channelIndex, -1)
                        if (channel >= 0) add(channel)
                    }
                },
                hardwareVolumeProtocol = hardwareVolume
                    ?.optString("protocol")
                    ?.trim()
                    ?.takeIf { it.isNotEmpty() },
                hardwareVolumeRecipient = hardwareVolume
                    ?.optString("recipient")
                    ?.takeIf { it == "device" || it == "interface" }
                    ?: "interface",
                hardwareVolumeMinQ8_8 = hardwareVolumeRange.q8_8("minDb"),
                hardwareVolumeMaxQ8_8 = hardwareVolumeRange.q8_8("maxDb"),
                hardwareVolumeStepQ8_8 = hardwareVolumeRange.q8_8("stepDb"),
                hardwareVolumeMuteQ8_8 = hardwareVolumeRange.q8_8("muteDb"),
                hardwareVolumeEnabled = if (hardwareVolume?.has("enabled") == true) {
                    hardwareVolume.optBoolean("enabled")
                } else {
                    null
                },
                hardwareVolumeDsdSupported = if (hardwareVolume?.has("dsdSupported") == true) {
                    hardwareVolume.optBoolean("dsdSupported")
                } else {
                    null
                },
                flags = buildList {
                    if (flagsArray != null) {
                        for (flagIndex in 0 until flagsArray.length()) {
                            flagsArray.optString(flagIndex).takeIf { it.isNotEmpty() }?.let(::add)
                        }
                    }
                },
            )
        }
    }

    fun matchQuirk(
        entries: List<Pair<String, DacQuirk>>,
        vendorId: Int,
        productId: Int,
    ): DacQuirk? {
        val exactKey = matchKey(vendorId, productId)
        val vendorKey = matchKey(vendorId, null)
        return entries.firstOrNull { it.first == exactKey }?.second
            ?: entries.firstOrNull { it.first == vendorKey }?.second
    }

    private fun matchKey(vendorId: Int, productId: Int?): String =
        "${hex(vendorId)}:${productId?.let { hex(it) } ?: "*"}"

    private fun hex(value: Int): String = "0x%04x".format(value)

    private fun normalizeId(raw: String?): String? {
        if (raw.isNullOrBlank()) {
            return null
        }
        val parsed = raw.trim().removePrefix("0x").removePrefix("0X").toIntOrNull(16)
            ?: return null
        return hex(parsed)
    }

    private fun JSONObject?.q8_8(key: String): Int? {
        if (this?.has(key) != true) return null
        val value = optDouble(key, Double.NaN)
        return value.takeIf { it.isFinite() }?.let { (it * 256.0).roundToInt() }
    }
}
