package com.afalphy.sylvakru

import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

// 手工构造 KB 级的最小 DSF/DFF 头验证解析、位序与块交错（不提交任何版权音频）
class UsbDsdTest {
    @get:Rule
    val temporaryFolder = TemporaryFolder()

    // ---- DSF ----

    private fun buildDsf(
        channels: Int,
        sampleRate: Int,
        bitsPerSample: Int,
        blockSize: Int,
        channelData: List<ByteArray>,
    ): File {
        val bytesPerChannel = channelData[0].size
        val blocks = (bytesPerChannel + blockSize - 1) / blockSize
        val audio = ByteArrayOutputStream()
        for (block in 0 until blocks) {
            for (channel in 0 until channels) {
                val data = channelData[channel]
                for (index in 0 until blockSize) {
                    val offset = block * blockSize + index
                    audio.write(if (offset < data.size) data[offset].toInt() and 0xff else 0)
                }
            }
        }
        val audioBytes = audio.toByteArray()

        val out = ByteArrayOutputStream()
        out.write("DSD ".toByteArray())
        out.writeLongLe(28)
        out.writeLongLe(28L + 52L + 12L + audioBytes.size)
        out.writeLongLe(0) // 无 ID3 元数据
        out.write("fmt ".toByteArray())
        out.writeLongLe(52)
        out.writeIntLe(1) // formatVersion
        out.writeIntLe(0) // formatId = DSD raw
        out.writeIntLe(2) // channelType
        out.writeIntLe(channels)
        out.writeIntLe(sampleRate)
        out.writeIntLe(bitsPerSample)
        out.writeLongLe(bytesPerChannel * 8L) // sampleCount（每通道位数）
        out.writeIntLe(blockSize)
        out.writeIntLe(0) // reserved
        out.write("data".toByteArray())
        out.writeLongLe(12L + audioBytes.size)
        out.write(audioBytes)

        val file = temporaryFolder.newFile("sample.dsf")
        file.writeBytes(out.toByteArray())
        return file
    }

    @Test
    fun dsfLsbFirstBlocksAreInterleavedAndBitReversed() {
        // 2 通道、块大小 4、每通道 6 字节 → 2 个块组（第二块组半满）
        val left = byteArrayOf(0x01, 0x02, 0x03, 0x04, 0x05, 0x06)
        val right = byteArrayOf(0x11, 0x12, 0x13, 0x14, 0x15, 0x16)
        val file = buildDsf(2, 2822400, 1, 4, listOf(left, right))

        DsdFileReader.open(file).use { reader ->
            assertEquals("dsf", reader.formatName)
            assertEquals(2822400, reader.sampleRate)
            assertEquals(2, reader.channels)
            assertEquals(64, reader.dsdMultiple)
            assertEquals(176400, reader.dopFrameRate)
            // 6 字节 × 8 位 / 2822400 Hz ≈ 0.017 ms → 截断为 0
            assertEquals(48 * 1000L / 2822400, reader.durationMs)

            val output = readAll(reader)
            // LSB-first 位反转后逐字节交错：L0 R0 L1 R1 …
            val expected = ByteArray(12)
            for (index in 0 until 6) {
                expected[index * 2] = reverseBits(left[index])
                expected[index * 2 + 1] = reverseBits(right[index])
            }
            assertArrayEquals(expected, output)
        }
    }

    @Test
    fun dsfMsbFirstBytesPassThrough() {
        val left = byteArrayOf(0x0F, 0x33.toByte())
        val right = byteArrayOf(0xF0.toByte(), 0xCC.toByte())
        val file = buildDsf(2, 5644800, 8, 2, listOf(left, right))

        DsdFileReader.open(file).use { reader ->
            assertEquals(128, reader.dsdMultiple)
            assertArrayEquals(
                byteArrayOf(0x0F, 0xF0.toByte(), 0x33, 0xCC.toByte()),
                readAll(reader),
            )
        }
    }

    @Test
    fun dsfSeekAlignsToBlockBoundary() {
        val perChannel = ByteArray(4096 * 3) { (it % 251).toByte() }
        val file = buildDsf(2, 2822400, 8, 4096, listOf(perChannel, perChannel))

        DsdFileReader.open(file).use { reader ->
            // 目标位置换算后落在块中间，应对齐回块边界
            val targetMs = 4100L * 8_000L / 2822400L + 1
            val actualMs = reader.seekTo(targetMs)
            assertEquals(4096L * 8_000L / 2822400L, actualMs)

            val buffer = ByteArray(8)
            assertEquals(8, reader.read(buffer))
            // 对齐到第二块起点：每通道第 4096 字节
            assertEquals(perChannel[4096], buffer[0])
            assertEquals(perChannel[4096], buffer[1])
        }
    }

    // ---- DFF ----

    private fun buildDff(
        channels: Int,
        sampleRate: Int,
        compression: String,
        audio: ByteArray,
    ): File {
        val prop = ByteArrayOutputStream()
        prop.write("SND ".toByteArray())
        prop.write("FS  ".toByteArray())
        prop.writeLongBe(4)
        prop.writeIntBe(sampleRate)
        prop.write("CHNL".toByteArray())
        prop.writeLongBe(2L + channels * 4L)
        prop.writeShortBe(channels)
        repeat(channels) { prop.write("SLFT".toByteArray()) }
        prop.write("CMPR".toByteArray())
        prop.writeLongBe(5) // 4 字节压缩类型 + 1 字节名字长度（奇数长度验证偶数对齐）
        prop.write(compression.toByteArray())
        prop.write(0)
        prop.write(0) // 对齐填充
        val propBytes = prop.toByteArray()

        val body = ByteArrayOutputStream()
        body.write("DSD ".toByteArray())
        body.write("FVER".toByteArray())
        body.writeLongBe(4)
        body.writeIntBe(0x01050000)
        body.write("PROP".toByteArray())
        body.writeLongBe(propBytes.size.toLong() - 1) // 声明大小不含对齐填充字节
        body.write(propBytes)
        body.write((if (compression == "DST ") "DST " else "DSD ").toByteArray())
        body.writeLongBe(audio.size.toLong())
        body.write(audio)
        val bodyBytes = body.toByteArray()

        val out = ByteArrayOutputStream()
        out.write("FRM8".toByteArray())
        out.writeLongBe(bodyBytes.size.toLong())
        out.write(bodyBytes)

        val file = temporaryFolder.newFile("sample.dff")
        file.writeBytes(out.toByteArray())
        return file
    }

    @Test
    fun dffInterleavedBytesPassThrough() {
        val audio = byteArrayOf(0x01, 0x11, 0x02, 0x12, 0x03, 0x13)
        val file = buildDff(2, 2822400, "DSD ", audio)

        DsdFileReader.open(file).use { reader ->
            assertEquals("dff", reader.formatName)
            assertEquals(2822400, reader.sampleRate)
            assertEquals(2, reader.channels)
            assertArrayEquals(audio, readAll(reader))
        }
    }

    @Test
    fun dffSeekAlignsToDopFramePair() {
        val audio = ByteArray(64) { it.toByte() }
        // 用 8000 Hz 的假速率让 1 ms 恰好等于每通道 1 字节，便于构造奇数目标位置
        val file = buildDff(2, 8000, "DSD ", audio)

        DsdFileReader.open(file).use { reader ->
            // 每通道 32 字节；定位到第 3 字节应对齐回第 2 字节（DoP 双字节边界）
            assertEquals(2, reader.seekTo(3))
            val buffer = ByteArray(4)
            assertEquals(4, reader.read(buffer))
            // 交错流里每通道第 2 字节从下标 4 开始
            assertArrayEquals(byteArrayOf(4, 5, 6, 7), buffer)
        }
    }

    @Test
    fun dffStreamingUsesDeclaredSizeAndGatesReads() {
        val audio = ByteArray(64) { it.toByte() }
        val full = buildDff(2, 8000, "DSD ", audio)
        val fullBytes = full.readBytes()
        val dataStart = fullBytes.size - audio.size
        // 只写入头部 + 前 4 字节数据，模拟仍在下载的 .part 文件
        val part = temporaryFolder.newFile("stream.dff")
        part.writeBytes(fullBytes.copyOfRange(0, dataStart + 4))

        DsdFileReader.open(part, streaming = true).use { reader ->
            // 时长按 chunk 头声明值取，而不是当前文件长度（每通道 32 字节 → 32 ms）
            assertEquals(32, reader.durationMs)
            assertTrue(reader.canReadAt(part.length()))
            val buffer = ByteArray(4)
            assertEquals(4, reader.read(buffer))
            // 下一帧还没下载到，不能读（否则会被误判成文件结尾）
            assertTrue(!reader.canReadAt(part.length()))
            // 模拟下载完成：其余数据就位后能一直读到声明的结尾
            part.writeBytes(fullBytes)
            assertTrue(reader.canReadAt(part.length()))
            assertEquals(60, readAll(reader).size)
        }
    }

    @Test
    fun dsfStreamingCanReadAtRequiresFullBlockGroup() {
        val perChannel = ByteArray(8) { (it + 1).toByte() }
        val full = buildDsf(2, 2822400, 8, 4, listOf(perChannel, perChannel))
        val fullBytes = full.readBytes()
        val dataStart = fullBytes.size - 16
        // 第一个块组完整，第二个块组缺最后 1 字节
        val part = temporaryFolder.newFile("stream.dsf")
        part.writeBytes(fullBytes.copyOfRange(0, dataStart + 8 + 7))

        DsdFileReader.open(part, streaming = true).use { reader ->
            assertTrue(reader.canReadAt(part.length()))
            val buffer = ByteArray(8)
            assertEquals(8, reader.read(buffer))
            // 第二块组按 planar 布局需要 (channels-1)×blockSize+valid 字节齐全
            assertTrue(!reader.canReadAt(part.length()))
            part.writeBytes(fullBytes)
            assertTrue(reader.canReadAt(part.length()))
            assertEquals(8, reader.read(buffer))
        }
    }

    @Test
    fun dffDstCompressionIsRejected() {
        val file = buildDff(2, 2822400, "DST ", ByteArray(8))
        try {
            DsdFileReader.open(file).use { }
            throw AssertionError("DST DFF should be rejected.")
        } catch (error: IOException) {
            assertTrue(error.message!!.contains("DST"))
        }
    }

    // ---- DoP ----

    @Test
    fun dopMarkerAlternatesAndBytesArePackedLittleEndian() {
        val packetizer = DopPacketizer(2)
        // 两帧：帧 1 取 L=0xA1/0xA2、R=0xB1/0xB2；帧 2 取 L=0xC1/0xC2、R=0xD1/0xD2
        val output = packetizer.encode(
            byteArrayOf(
                0xA1.toByte(), 0xB1.toByte(), 0xA2.toByte(), 0xB2.toByte(),
                0xC1.toByte(), 0xD1.toByte(), 0xC2.toByte(), 0xD2.toByte(),
            ),
        )
        // 24-bit 小端：低字节=时间靠后的 DSD 字节，中字节=时间靠前，高字节=标记
        assertArrayEquals(
            byteArrayOf(
                0xA2.toByte(), 0xA1.toByte(), 0x05,
                0xB2.toByte(), 0xB1.toByte(), 0x05,
                0xC2.toByte(), 0xC1.toByte(), 0xFA.toByte(),
                0xD2.toByte(), 0xD1.toByte(), 0xFA.toByte(),
            ),
            output,
        )
    }

    @Test
    fun dopCarryKeepsPartialFrameAcrossWrites() {
        val packetizer = DopPacketizer(2)
        val first = packetizer.encode(byteArrayOf(0xA1.toByte(), 0xB1.toByte(), 0xA2.toByte()))
        assertEquals(0, first.size)
        val second = packetizer.encode(byteArrayOf(0xB2.toByte()))
        assertArrayEquals(
            byteArrayOf(
                0xA2.toByte(), 0xA1.toByte(), 0x05,
                0xB2.toByte(), 0xB1.toByte(), 0x05,
            ),
            second,
        )
    }

    @Test
    fun dopSilenceUses0x69AndKeepsMarkerPhase() {
        val packetizer = DopPacketizer(2)
        packetizer.encode(byteArrayOf(0xA1.toByte(), 0xB1.toByte(), 0xA2.toByte(), 0xB2.toByte()))
        val silence = packetizer.encodeSilence(2)
        assertArrayEquals(
            byteArrayOf(
                0x69, 0x69, 0xFA.toByte(),
                0x69, 0x69, 0xFA.toByte(),
                0x69, 0x69, 0x05,
                0x69, 0x69, 0x05,
            ),
            silence,
        )
    }

    @Test
    fun dopDrainPadsTailWithSilence() {
        val packetizer = DopPacketizer(2)
        packetizer.encode(byteArrayOf(0xA1.toByte(), 0xB1.toByte()))
        assertArrayEquals(
            byteArrayOf(
                0x69, 0xA1.toByte(), 0x05,
                0x69, 0xB1.toByte(), 0x05,
            ),
            packetizer.drain(),
        )
        assertEquals(0, packetizer.drain().size)
    }

    @Test
    fun dopResetRestoresMarkerPhase() {
        val packetizer = DopPacketizer(1)
        packetizer.encode(byteArrayOf(0x01, 0x02))
        packetizer.reset()
        val output = packetizer.encode(byteArrayOf(0x03, 0x04))
        assertEquals(0x05, output[2].toInt() and 0xff)
    }

    @Test
    fun nonDsdRateHasNoMultiple() {
        val file = buildDff(2, 3072000, "DSD ", ByteArray(4))
        DsdFileReader.open(file).use { reader ->
            assertNull(reader.dsdMultiple)
        }
    }

    // ---- Native DSD ----

    @Test
    fun nativeU32leGroupsPerChannelBytesInTimeOrder() {
        val packetizer = NativeDsdPacketizer(2, 4, bigEndian = false)
        // 交错流 L0 R0 L1 R1 L2 R2 L3 R3
        val output = packetizer.encode(
            byteArrayOf(0x01, 0x11, 0x02, 0x12, 0x03, 0x13, 0x04, 0x14),
        )
        // u32le：每声道连续 4 字节按时间正序 [L0..L3][R0..R3]
        assertArrayEquals(
            byteArrayOf(0x01, 0x02, 0x03, 0x04, 0x11, 0x12, 0x13, 0x14),
            output,
        )
    }

    @Test
    fun nativeU32beReversesBytesWithinSlot() {
        val packetizer = NativeDsdPacketizer(2, 4, bigEndian = true)
        val output = packetizer.encode(
            byteArrayOf(0x01, 0x11, 0x02, 0x12, 0x03, 0x13, 0x04, 0x14),
        )
        // u32be：LSB（最早字节）在 word 高地址，组内倒序
        assertArrayEquals(
            byteArrayOf(0x04, 0x03, 0x02, 0x01, 0x14, 0x13, 0x12, 0x11),
            output,
        )
    }

    @Test
    fun nativeU16leCarryAcrossWrites() {
        val packetizer = NativeDsdPacketizer(2, 2, bigEndian = false)
        assertEquals(0, packetizer.encode(byteArrayOf(0x01, 0x11, 0x02)).size)
        assertArrayEquals(
            byteArrayOf(0x01, 0x02, 0x11, 0x12),
            packetizer.encode(byteArrayOf(0x12)),
        )
    }

    @Test
    fun nativeSilenceAndDrainUse0x69() {
        val packetizer = NativeDsdPacketizer(2, 2, bigEndian = false)
        assertArrayEquals(ByteArray(8) { 0x69 }, packetizer.encodeSilence(2))
        packetizer.encode(byteArrayOf(0x01, 0x11))
        assertArrayEquals(byteArrayOf(0x01, 0x69, 0x11, 0x69), packetizer.drain())
        assertEquals(0, packetizer.drain().size)
    }

    @Test
    fun nativeBytesPerSampleMapping() {
        assertEquals(1, nativeDsdBytesPerSample("u8"))
        assertEquals(2, nativeDsdBytesPerSample("u16le"))
        assertEquals(4, nativeDsdBytesPerSample("u32le"))
        assertEquals(4, nativeDsdBytesPerSample("u32be"))
        assertNull(nativeDsdBytesPerSample(null))
        assertNull(nativeDsdBytesPerSample("dop"))
    }

    // ---- 工具 ----

    private fun readAll(reader: DsdFileReader): ByteArray {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(16)
        while (true) {
            val count = reader.read(buffer)
            if (count < 0) break
            out.write(buffer, 0, count)
        }
        return out.toByteArray()
    }

    private fun reverseBits(byte: Byte): Byte {
        var value = byte.toInt() and 0xff
        var reversed = 0
        repeat(8) {
            reversed = (reversed shl 1) or (value and 1)
            value = value shr 1
        }
        return reversed.toByte()
    }

    private fun ByteArrayOutputStream.writeIntLe(value: Int) {
        for (index in 0 until 4) {
            write((value ushr (index * 8)) and 0xff)
        }
    }

    private fun ByteArrayOutputStream.writeLongLe(value: Long) {
        for (index in 0 until 8) {
            write(((value ushr (index * 8)) and 0xff).toInt())
        }
    }

    private fun ByteArrayOutputStream.writeIntBe(value: Int) {
        for (index in 3 downTo 0) {
            write((value ushr (index * 8)) and 0xff)
        }
    }

    private fun ByteArrayOutputStream.writeShortBe(value: Int) {
        write((value ushr 8) and 0xff)
        write(value and 0xff)
    }

    private fun ByteArrayOutputStream.writeLongBe(value: Long) {
        for (index in 7 downTo 0) {
            write(((value ushr (index * 8)) and 0xff).toInt())
        }
    }
}
