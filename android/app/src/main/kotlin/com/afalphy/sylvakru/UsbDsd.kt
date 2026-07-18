package com.afalphy.sylvakru

import java.io.Closeable
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile

// DSD 静音字节是 0x69（01101001，均值为半幅的交替位型），不是 0x00。
// 暂停/垫包必须发 0x69，发零会让 DAC 掉出 DSD 模式并可能爆音。
const val DSD_SILENCE_BYTE = 0x69

/**
 * 统一读取 DSF/DFF 文件，屏蔽两种容器差异，输出统一约定的 DSD 字节流：
 * MSB-first、逐字节声道交错（L R L R…）。纯 JVM 实现，不依赖 Android API，可直接单元测试。
 *
 * - DSF（Sony，小端）：采样按每通道 blockSizePerChannel 字节的块 planar 存放，读取时转交错；
 *   bitsPerSample=1 表示每字节 LSB-first，需查表位反转；=8 表示 MSB-first，直接透传。
 * - DFF（Philips，大端 IFF）：数据本身就是 MSB-first 逐字节交错，直接透传；
 *   DST 压缩的 DFF 不支持，open 时抛错。
 */
class DsdFileReader private constructor(
    private val input: RandomAccessFile,
    val formatName: String,
    val sampleRate: Int,
    val channels: Int,
    private val dataStart: Long,
    private val bytesPerChannel: Long,
    private val blockSizePerChannel: Int,
    private val lsbFirst: Boolean,
) : Closeable {
    // 每通道已交付给调用方的字节数，即当前播放位置
    private var positionBytesPerChannel = 0L

    // DSF 专用：一个块组（blockSizePerChannel × channels）转交错后的缓冲
    private val chunk = if (blockSizePerChannel > 0) ByteArray(blockSizePerChannel * channels) else ByteArray(0)
    private var chunkLength = 0
    private var chunkOffset = 0
    // DSF 专用：已从文件装载进 chunk 的每通道字节数
    private var loadedBytesPerChannel = 0L

    val durationMs: Long get() = bytesPerChannel * 8_000L / sampleRate
    val positionMs: Long get() = positionBytesPerChannel * 8_000L / sampleRate

    /** DSD 倍率（64/128/256/512），速率不在 44.1k 族时为 null。 */
    val dsdMultiple: Int? get() = if (sampleRate % 44100 == 0) sampleRate / 44100 else null

    /** DoP 输出的 PCM 帧率 = DSD 速率 ÷ 16（每帧每声道装 2 个 DSD 字节）。 */
    val dopFrameRate: Int get() = sampleRate / 16

    /**
     * 读取交错 DSD 字节流。返回写入 [out] 的字节数（总是 channels 的整数倍），文件结束返回 -1。
     * 一次调用最多交付一个内部块的余量，调用方循环读取即可。
     */
    fun read(out: ByteArray): Int {
        if (blockSizePerChannel > 0) {
            return readDsf(out)
        }
        val remaining = (bytesPerChannel - positionBytesPerChannel) * channels
        if (remaining <= 0L) {
            return -1
        }
        val wanted = (out.size / channels * channels).toLong().coerceAtMost(remaining).toInt()
        if (wanted <= 0) {
            return -1
        }
        var readTotal = 0
        while (readTotal < wanted) {
            val count = input.read(out, readTotal, wanted - readTotal)
            if (count < 0) {
                break
            }
            readTotal += count
        }
        // 文件比头部声明的短：把不完整的尾部对齐丢弃
        val delivered = readTotal / channels * channels
        if (delivered <= 0) {
            positionBytesPerChannel = bytesPerChannel
            return -1
        }
        positionBytesPerChannel += delivered / channels
        return delivered
    }

    private fun readDsf(out: ByteArray): Int {
        if (chunkOffset >= chunkLength && !loadNextDsfBlock()) {
            return -1
        }
        val count = minOf(out.size / channels * channels, chunkLength - chunkOffset)
        if (count <= 0) {
            return -1
        }
        System.arraycopy(chunk, chunkOffset, out, 0, count)
        chunkOffset += count
        positionBytesPerChannel += count / channels
        return count
    }

    private fun loadNextDsfBlock(): Boolean {
        val valid = (bytesPerChannel - loadedBytesPerChannel).coerceAtMost(blockSizePerChannel.toLong()).toInt()
        if (valid <= 0) {
            return false
        }
        val groupIndex = loadedBytesPerChannel / blockSizePerChannel
        val groupBytes = blockSizePerChannel.toLong() * channels
        input.seek(dataStart + groupIndex * groupBytes)
        val raw = ByteArray(blockSizePerChannel * channels)
        var readTotal = 0
        while (readTotal < raw.size) {
            val count = input.read(raw, readTotal, raw.size - readTotal)
            if (count < 0) {
                break
            }
            readTotal += count
        }
        // planar 块转逐字节交错；LSB-first 时同步做位反转
        val usable = minOf(valid, readTotal / channels)
        if (usable <= 0) {
            loadedBytesPerChannel = bytesPerChannel
            return false
        }
        for (index in 0 until usable) {
            for (channel in 0 until channels) {
                val byte = raw[channel * blockSizePerChannel + index]
                chunk[index * channels + channel] = if (lsbFirst) BIT_REVERSE_TABLE[byte.toInt() and 0xff] else byte
            }
        }
        chunkLength = usable * channels
        chunkOffset = 0
        loadedBytesPerChannel += usable
        return true
    }

    /**
     * 流式下载中调用：按当前已下载的文件长度 [fileLength] 判断下一次 [read]
     * 能否交付数据而不把"数据还没下到"误判成文件结尾。
     * DSF 要求下一个块组所需字节齐全（避免半块重复交付），DFF 只要求至少一帧。
     * 已到真实结尾时返回 true，让 [read] 正常返回 -1。
     */
    fun canReadAt(fileLength: Long): Boolean {
        if (positionBytesPerChannel >= bytesPerChannel) {
            return true
        }
        if (blockSizePerChannel > 0) {
            if (chunkOffset < chunkLength) {
                return true
            }
            val valid = (bytesPerChannel - loadedBytesPerChannel)
                .coerceAtMost(blockSizePerChannel.toLong())
            if (valid <= 0) {
                return true
            }
            val groupStart = dataStart +
                loadedBytesPerChannel / blockSizePerChannel * blockSizePerChannel * channels
            // planar 块组内最后一个声道的段也要够 valid 字节
            return fileLength >= groupStart + (channels - 1).toLong() * blockSizePerChannel + valid
        }
        return fileLength >= dataStart + (positionBytesPerChannel + 1) * channels
    }

    /**
     * 定位到 [positionMs] 附近：DSF 对齐到块边界，DFF 对齐到 DoP 双字节边界。
     * 返回对齐后的实际位置（毫秒），用于进度上报。
     */
    fun seekTo(positionMs: Long): Long {
        val target = (positionMs.coerceAtLeast(0L) * sampleRate / 8_000L).coerceAtMost(bytesPerChannel)
        val aligned = if (blockSizePerChannel > 0) {
            target / blockSizePerChannel * blockSizePerChannel
        } else {
            target / 2L * 2L
        }
        if (blockSizePerChannel > 0) {
            loadedBytesPerChannel = aligned
            chunkLength = 0
            chunkOffset = 0
        } else {
            input.seek(dataStart + aligned * channels)
        }
        positionBytesPerChannel = aligned
        return aligned * 8_000L / sampleRate
    }

    override fun close() {
        input.close()
    }

    companion object {
        // LSB-first → MSB-first 的每字节位反转查表
        private val BIT_REVERSE_TABLE = ByteArray(256) { index ->
            var value = index
            var reversed = 0
            repeat(8) {
                reversed = (reversed shl 1) or (value and 1)
                value = value shr 1
            }
            reversed.toByte()
        }

        /**
         * [streaming] 为 true 表示文件还在下载增长中：DFF 的数据大小按 chunk 头
         * 声明值取（此刻文件长度不足以作截断依据），可读进度由调用方配合
         * [canReadAt] 控制。
         */
        fun open(file: File, streaming: Boolean = false): DsdFileReader {
            val input = RandomAccessFile(file, "r")
            try {
                val magic = ByteArray(4)
                input.readFully(magic)
                return when (String(magic, Charsets.US_ASCII)) {
                    "DSD " -> openDsf(input)
                    "FRM8" -> openDff(input, streaming)
                    else -> throw IOException("Not a DSF/DFF file.")
                }
            } catch (error: Throwable) {
                runCatching { input.close() }
                throw error
            }
        }

        private fun openDsf(input: RandomAccessFile): DsdFileReader {
            val dsdChunkSize = input.readLongLe()
            if (dsdChunkSize < 28L) {
                throw IOException("Invalid DSF 'DSD ' chunk size: $dsdChunkSize")
            }
            input.seek(dsdChunkSize)

            val fmtMagic = ByteArray(4)
            input.readFully(fmtMagic)
            if (String(fmtMagic, Charsets.US_ASCII) != "fmt ") {
                throw IOException("DSF 'fmt ' chunk is missing.")
            }
            val fmtChunkSize = input.readLongLe()
            input.readIntLe() // formatVersion
            val formatId = input.readIntLe()
            if (formatId != 0) {
                throw IOException("Unsupported DSF format id: $formatId")
            }
            input.readIntLe() // channelType
            val channels = input.readIntLe()
            val sampleRate = input.readIntLe()
            val bitsPerSample = input.readIntLe()
            val sampleCount = input.readLongLe()
            // 规范允许 blockSizePerChannel 不是 4096，按 header 实际值处理
            val blockSize = input.readIntLe()
            if (channels !in 1..6 || sampleRate <= 0 || blockSize <= 0) {
                throw IOException(
                    "Invalid DSF fmt: channels=$channels, sampleRate=$sampleRate, blockSize=$blockSize",
                )
            }
            if (bitsPerSample != 1 && bitsPerSample != 8) {
                throw IOException("Unsupported DSF bitsPerSample: $bitsPerSample")
            }

            input.seek(dsdChunkSize + fmtChunkSize)
            val dataMagic = ByteArray(4)
            input.readFully(dataMagic)
            if (String(dataMagic, Charsets.US_ASCII) != "data") {
                throw IOException("DSF 'data' chunk is missing.")
            }
            val dataChunkSize = input.readLongLe()
            val dataStart = dsdChunkSize + fmtChunkSize + 12
            val audioBytes = if (dataChunkSize >= 12L) dataChunkSize - 12L else input.length() - dataStart
            val bytesPerChannel = minOf(sampleCount / 8L, audioBytes / channels)
            input.seek(dataStart)
            return DsdFileReader(
                input = input,
                formatName = "dsf",
                sampleRate = sampleRate,
                channels = channels,
                dataStart = dataStart,
                bytesPerChannel = bytesPerChannel,
                blockSizePerChannel = blockSize,
                lsbFirst = bitsPerSample == 1,
            )
        }

        private fun openDff(input: RandomAccessFile, streaming: Boolean = false): DsdFileReader {
            val formSize = input.readLongBe()
            val formType = ByteArray(4)
            input.readFully(formType)
            if (String(formType, Charsets.US_ASCII) != "DSD ") {
                throw IOException("Unsupported DFF form type.")
            }

            var sampleRate = 0
            var channels = 0
            var dataStart = -1L
            var dataSize = 0L
            var offset = 16L
            val formEnd = minOf(12L + formSize, input.length())
            val id = ByteArray(4)
            while (offset + 12 <= formEnd) {
                input.seek(offset)
                input.readFully(id)
                val chunkSize = input.readLongBe()
                when (String(id, Charsets.US_ASCII)) {
                    "PROP" -> {
                        val propType = ByteArray(4)
                        input.readFully(propType)
                        if (String(propType, Charsets.US_ASCII) == "SND ") {
                            var propOffset = offset + 16
                            val propEnd = minOf(offset + 12 + chunkSize, formEnd)
                            while (propOffset + 12 <= propEnd) {
                                input.seek(propOffset)
                                input.readFully(id)
                                val subSize = input.readLongBe()
                                when (String(id, Charsets.US_ASCII)) {
                                    "FS  " -> sampleRate = input.readIntBe()
                                    "CHNL" -> channels = input.readShortBe()
                                    "CMPR" -> {
                                        val compression = ByteArray(4)
                                        input.readFully(compression)
                                        if (String(compression, Charsets.US_ASCII) == "DST ") {
                                            throw IOException("DST-compressed DFF is not supported.")
                                        }
                                    }
                                }
                                // IFF chunk 按偶数字节对齐
                                propOffset += 12 + subSize + (subSize and 1L)
                            }
                        }
                    }
                    "DSD " -> {
                        dataStart = offset + 12
                        dataSize = chunkSize
                    }
                    "DST " -> throw IOException("DST-compressed DFF is not supported.")
                }
                offset += 12 + chunkSize + (chunkSize and 1L)
            }

            if (sampleRate <= 0 || channels !in 1..6 || dataStart < 0L) {
                throw IOException(
                    "Invalid DFF: sampleRate=$sampleRate, channels=$channels, hasData=${dataStart >= 0}",
                )
            }
            // 流式下载中文件长度还在增长，数据大小只信 chunk 头声明值
            val audioBytes = if (streaming) dataSize else minOf(dataSize, input.length() - dataStart)
            input.seek(dataStart)
            return DsdFileReader(
                input = input,
                formatName = "dff",
                sampleRate = sampleRate,
                channels = channels,
                dataStart = dataStart,
                bytesPerChannel = audioBytes / channels,
                blockSizePerChannel = 0,
                lsbFirst = false,
            )
        }

        private fun RandomAccessFile.readIntLe(): Int {
            val bytes = ByteArray(4)
            readFully(bytes)
            return (bytes[0].toInt() and 0xff) or
                ((bytes[1].toInt() and 0xff) shl 8) or
                ((bytes[2].toInt() and 0xff) shl 16) or
                ((bytes[3].toInt() and 0xff) shl 24)
        }

        private fun RandomAccessFile.readLongLe(): Long {
            var value = 0L
            val bytes = ByteArray(8)
            readFully(bytes)
            for (index in 7 downTo 0) {
                value = (value shl 8) or (bytes[index].toLong() and 0xff)
            }
            return value
        }

        private fun RandomAccessFile.readIntBe(): Int {
            val bytes = ByteArray(4)
            readFully(bytes)
            return ((bytes[0].toInt() and 0xff) shl 24) or
                ((bytes[1].toInt() and 0xff) shl 16) or
                ((bytes[2].toInt() and 0xff) shl 8) or
                (bytes[3].toInt() and 0xff)
        }

        private fun RandomAccessFile.readShortBe(): Int {
            val bytes = ByteArray(2)
            readFully(bytes)
            return ((bytes[0].toInt() and 0xff) shl 8) or (bytes[1].toInt() and 0xff)
        }

        private fun RandomAccessFile.readLongBe(): Long {
            var value = 0L
            val bytes = ByteArray(8)
            readFully(bytes)
            for (index in 0 until 8) {
                value = (value shl 8) or (bytes[index].toLong() and 0xff)
            }
            return value
        }
    }
}

/**
 * DSD 字节流编码器的统一口径（DoP / Native DSD 共用）：输入都是 DsdFileReader 的
 * MSB-first 逐字节交错流，输出都交给 PcmIsoPacketizer 当普通 PCM 帧打包。
 * 会话级静音填充线程与写线程只依赖这三个方法，两种模式行为一致：
 * 静音一律 0x69，流一旦中断 DAC 就会掉出 DSD 模式（爆音/电流声）。
 */
interface DsdStreamEncoder {
    /** 编码 [data] 的前 [length] 字节，不足一帧的余量留到下次。 */
    fun encode(data: ByteArray, length: Int = data.size): ByteArray

    /** 生成 [frames] 帧 DSD 静音（0x69）。 */
    fun encodeSilence(frames: Int): ByteArray

    /** 把不足一帧的余量用 0x69 补齐成完整帧输出（无余量时返回空数组）。 */
    fun drain(): ByteArray
}

/**
 * 把 DsdFileReader 输出的交错 DSD 字节流封装成 DoP 24-bit PCM 采样流（小端，每采样 3 字节）。
 * 每帧每声道取 2 个连续 DSD 字节：sample24 = (marker shl 16) or (先到字节 shl 8) or 后到字节；
 * 标记逐帧在 0x05/0xFA 间交替，同一帧内各声道用相同标记。
 * 输出交给 PcmIsoPacketizer 当作普通 24-bit PCM（sampleRate = DSD 速率 ÷ 16），
 * 24→32 slot 的高位对齐移位恰好得到规范要求的"DoP 24 位放高位、低 8 位补零"。
 * 注意：DoP 数据被任何后续 DSP（音量、抖动、重采样）修改都会破坏标记、输出全幅噪声。
 */
class DopPacketizer(private val channels: Int) : DsdStreamEncoder {
    private val frameBytes = 2 * channels
    private var marker = 0x05
    private val carry = ByteArray(frameBytes)
    private var carryLength = 0

    override fun encode(data: ByteArray, length: Int): ByteArray {
        val total = carryLength + length
        val frames = total / frameBytes
        val output = ByteArray(frames * channels * 3)
        var outputOffset = 0
        var consumed = 0
        repeat(frames) {
            // 帧内逐声道装两个字节：时间靠前的放 bits 15-8
            for (channel in 0 until channels) {
                val early = byteAt(data, consumed + channel)
                val late = byteAt(data, consumed + channels + channel)
                output[outputOffset + channel * 3] = late
                output[outputOffset + channel * 3 + 1] = early
                output[outputOffset + channel * 3 + 2] = marker.toByte()
            }
            consumed += frameBytes
            outputOffset += channels * 3
            marker = if (marker == 0x05) 0xFA else 0x05
        }

        // 更新余量：把没吃完的尾巴挪到 carry 开头
        val leftover = total - frames * frameBytes
        if (leftover > 0) {
            val tail = ByteArray(leftover)
            for (index in 0 until leftover) {
                tail[index] = byteAt(data, frames * frameBytes + index)
            }
            System.arraycopy(tail, 0, carry, 0, leftover)
        }
        carryLength = leftover
        return output
    }

    /** DoP 静音：payload 0x69 0x69，标记正常交替。 */
    override fun encodeSilence(frames: Int): ByteArray {
        val output = ByteArray(frames * channels * 3)
        var outputOffset = 0
        val silence = DSD_SILENCE_BYTE.toByte()
        repeat(frames) {
            for (channel in 0 until channels) {
                output[outputOffset + channel * 3] = silence
                output[outputOffset + channel * 3 + 1] = silence
                output[outputOffset + channel * 3 + 2] = marker.toByte()
            }
            outputOffset += channels * 3
            marker = if (marker == 0x05) 0xFA else 0x05
        }
        return output
    }

    override fun drain(): ByteArray {
        if (carryLength == 0) {
            return ByteArray(0)
        }
        val padding = ByteArray(frameBytes - carryLength) { DSD_SILENCE_BYTE.toByte() }
        return encode(padding)
    }

    /** seek 后重置：标记回到起始相位，丢弃余量。 */
    fun reset() {
        marker = 0x05
        carryLength = 0
    }

    // 逻辑上 carry 与 data 是拼接的一段流，按拼接后的下标取字节
    private fun byteAt(data: ByteArray, index: Int): Byte {
        return if (index < carryLength) carry[index] else data[index - carryLength]
    }
}

/** quirk `nativeDsd.format` → 每声道每帧字节数；未知格式返回 null。 */
fun nativeDsdBytesPerSample(format: String?): Int? = when (format) {
    "u8" -> 1
    "u16le" -> 2
    "u32le", "u32be" -> 4
    else -> null
}

/**
 * Native DSD 打包：把交错 DSD 字节流按设备期望的 subslot 排列重组，直接当
 * "bitDepth = subslot 位宽的 PCM" 交给 PcmIsoPacketizer（帧率 = DSD 速率 ÷ 8 ÷ 每采样字节数），
 * 无 DoP 标记、无任何数据修改，纯字节重排（对应 ALSA DSD_U8/U16_LE/U32_LE/U32_BE 语义）：
 * - LE：subslot 内存序 = 时间序（最早的字节在前）；
 * - BE：LSB（最早字节）在 word 高地址，subslot 组内字节倒序。
 * 静音同样是 0x69（重排后仍是 0x69），流中断一样会让 DAC 掉出 DSD 模式。
 */
class NativeDsdPacketizer(
    private val channels: Int,
    private val bytesPerSample: Int,
    private val bigEndian: Boolean,
) : DsdStreamEncoder {
    private val frameBytes = bytesPerSample * channels
    private val carry = ByteArray(frameBytes)
    private var carryLength = 0

    override fun encode(data: ByteArray, length: Int): ByteArray {
        val total = carryLength + length
        val frames = total / frameBytes
        val output = ByteArray(frames * frameBytes)
        var outputOffset = 0
        var consumed = 0
        repeat(frames) {
            // 交错流 L0 R0 L1 R1… → 每声道连续 bytesPerSample 字节（LE 时间正序 / BE 倒序）
            for (channel in 0 until channels) {
                for (sampleIndex in 0 until bytesPerSample) {
                    val slotIndex = if (bigEndian) bytesPerSample - 1 - sampleIndex else sampleIndex
                    output[outputOffset + channel * bytesPerSample + slotIndex] =
                        byteAt(data, consumed + sampleIndex * channels + channel)
                }
            }
            consumed += frameBytes
            outputOffset += frameBytes
        }

        val leftover = total - frames * frameBytes
        if (leftover > 0) {
            val tail = ByteArray(leftover)
            for (index in 0 until leftover) {
                tail[index] = byteAt(data, frames * frameBytes + index)
            }
            System.arraycopy(tail, 0, carry, 0, leftover)
        }
        carryLength = leftover
        return output
    }

    override fun encodeSilence(frames: Int): ByteArray {
        return ByteArray(frames * frameBytes) { DSD_SILENCE_BYTE.toByte() }
    }

    override fun drain(): ByteArray {
        if (carryLength == 0) {
            return ByteArray(0)
        }
        val padding = ByteArray(frameBytes - carryLength) { DSD_SILENCE_BYTE.toByte() }
        return encode(padding)
    }

    private fun byteAt(data: ByteArray, index: Int): Byte {
        return if (index < carryLength) carry[index] else data[index - carryLength]
    }
}
