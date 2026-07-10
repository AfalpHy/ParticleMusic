package com.afalphy.sylvakru

import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * USB 独占链路的进程内诊断日志缓冲。
 *
 * 所有 USB 相关的 [Log] 调用都改为经由这里转发：既保持 logcat 行为不变，
 * 又把最近 [MAX_ENTRIES] 条日志留在环形缓冲里，供“生成诊断报告”功能读取。
 * 普通用户拿不到 logcat，这个缓冲是他们能带走的第一手排查数据。
 */
object UsbDiagnostics {
    private const val MAX_ENTRIES = 500

    private val lock = Any()
    private val entries = ArrayDeque<String>()
    private val timeFormat = SimpleDateFormat("HH:mm:ss.SSS", Locale.US)

    fun i(tag: String, message: String) {
        Log.i(tag, message)
        record("I", tag, message)
    }

    fun w(tag: String, message: String) {
        Log.w(tag, message)
        record("W", tag, message)
    }

    fun w(tag: String, message: String, throwable: Throwable) {
        Log.w(tag, message, throwable)
        record("W", tag, "$message ${throwable.javaClass.simpleName}: ${throwable.message}")
    }

    fun d(tag: String, message: String) {
        Log.d(tag, message)
        record("D", tag, message)
    }

    fun e(tag: String, message: String) {
        Log.e(tag, message)
        record("E", tag, message)
    }

    /** 返回环形缓冲内最近的日志快照（时间升序），供诊断报告拼装。 */
    fun snapshot(): List<String> {
        synchronized(lock) {
            return entries.toList()
        }
    }

    private fun record(level: String, tag: String, message: String) {
        val line = "${timeFormat.format(Date())} $level/$tag: $message"
        synchronized(lock) {
            entries.addLast(line)
            while (entries.size > MAX_ENTRIES) {
                entries.removeFirst()
            }
        }
    }
}
