import 'package:flutter/material.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

String formatSampleRate(int? sampleRate, AppLocalizations l10n) {
  if (sampleRate == null || sampleRate <= 0) {
    return l10n.unknown;
  }

  // DSD 速率显示为 DSD64/128/…，而不是 2822.4 kHz
  if (sampleRate >= 2822400 && sampleRate % 44100 == 0) {
    return 'DSD${sampleRate ~/ 44100}';
  }

  final khz = sampleRate / 1000.0;
  if (khz == khz.roundToDouble()) {
    return '${khz.round()} kHz';
  }
  return '${khz.toStringAsFixed(1)} kHz';
}

String formatOutputSampleRate(UsbAudioStatus status, AppLocalizations l10n) {
  final exclusive = usbExclusivePlaybackStateNotifier.value;
  if (exclusive.active && exclusive.sampleRate != null) {
    return formatSampleRate(exclusive.sampleRate, l10n);
  }

  return formatSampleRate(
    status.preferredSampleRate ?? status.outputSampleRate,
    l10n,
  );
}

String formatOutputDeviceName(UsbAudioStatus status, AppLocalizations l10n) {
  if (!status.supported) {
    final name = status.outputDeviceName?.toLowerCase();
    if (name == null || name.contains('speaker') || name.contains('扬声器')) {
      return l10n.speaker;
    }
    return status.outputDeviceName!;
  }
  final device = _activeUsbDevice(status);
  if (device != null) {
    return device.name;
  }
  return status.outputDeviceName ?? 'USB DAC';
}

String formatBitrate(int? bitrate, AppLocalizations l10n) {
  if (bitrate == null || bitrate <= 0) {
    return l10n.unknown;
  }
  final kbps = bitrate >= 100000 ? (bitrate / 1000).round() : bitrate;
  return '$kbps kbps';
}

String formatSourceFileName(String? path, AppLocalizations l10n) {
  if (path == null || path.isEmpty) {
    return l10n.unknown;
  }
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isEmpty ? normalized : parts.last;
}

String formatOutputPortLabel(UsbAudioStatus status, AppLocalizations l10n) {
  if (!status.supported) {
    return formatOutputDeviceName(status, l10n);
  }
  final exclusive = usbExclusivePlaybackStateNotifier.value;
  if (exclusive.active) {
    return l10n.usbExclusive;
  }
  final name = _shortOutputName(status, l10n);
  return status.preferredApplied
      ? l10n.appliedPreference(name)
      : l10n.usbOutputLabel(name);
}

List<int?> buildSampleRateOptions(
  UsbAudioStatus status,
  int? sourceSampleRate,
) {
  final options = <int?>[null];
  final deviceId = status.bestAvailableDeviceId;
  UsbAudioDevice? activeDevice;

  for (final device in status.devices) {
    if (device.id == deviceId) {
      activeDevice = device;
      break;
    }
  }

  final preferredRates =
      activeDevice?.supportedMixerSampleRates.isNotEmpty == true
      ? activeDevice!.supportedMixerSampleRates
      : activeDevice?.sampleRates ?? const <int>[];
  final sortedRates = preferredRates.toSet().toList()..sort();

  options.addAll(sortedRates);
  if (sourceSampleRate != null &&
      sourceSampleRate > 0 &&
      UsbAudioPreferences.sampleRates.contains(sourceSampleRate) &&
      !options.contains(sourceSampleRate)) {
    options.add(sourceSampleRate);
  }
  return options;
}

int? preferredExclusiveSampleRate(
  UsbAudioStatus status,
  int? sourceSampleRate,
) {
  final fixedRate = usbAudioPreferences.preferredFixedSampleRate();
  if (fixedRate != null) {
    return fixedRate;
  }

  final matchedSourceRate = matchedSafeSampleRate(sourceSampleRate);
  final deviceRates = buildSampleRateOptions(status, null).whereType<int>();
  if (matchedSourceRate != null && deviceRates.contains(matchedSourceRate)) {
    return matchedSourceRate;
  }
  return bestExclusiveDeviceSampleRate(status);
}

int? bestExclusiveDeviceSampleRate(UsbAudioStatus status) {
  final rates = buildSampleRateOptions(status, null).whereType<int>().toList();
  if (rates.isEmpty) {
    return status.bestAvailableSampleRate;
  }
  rates.sort();
  return rates.last;
}

int? matchedSafeSampleRate(int? sourceSampleRate) {
  if (sourceSampleRate == null || sourceSampleRate <= 0) {
    return null;
  }

  final supportedRates = UsbAudioPreferences.sampleRates;
  if (supportedRates.contains(sourceSampleRate)) {
    return sourceSampleRate;
  }

  final sameFamilyRates =
      supportedRates.where((rate) => sourceSampleRate % rate == 0).toList()
        ..sort();
  if (sameFamilyRates.isNotEmpty) {
    return sameFamilyRates.last;
  }

  return supportedRates
      .where((rate) => rate <= sourceSampleRate)
      .fold<int?>(
        null,
        (best, rate) => best == null || rate > best ? rate : best,
      );
}

Future<UsbAudioStatus> applyExclusiveOutputForSong(
  UsbAudioStatus status,
  MyAudioMetadata? song,
) {
  return usbAudioService.applyPreferredOutput(
    deviceId: status.bestAvailableDeviceId,
    sampleRate: preferredExclusiveSampleRate(status, song?.samplerate),
    encoding: usbAudioPreferences.preferredEncoding(),
  );
}

class AudioOutputChip extends StatelessWidget {
  final MyAudioMetadata? song;
  final Color color;

  const AudioOutputChip({super.key, required this.song, required this.color});

  @override
  Widget build(BuildContext context) {
    // 同时监听系统 USB 状态、独占播放状态与独占开关：切歌/切独占/DSD 切换时
    // 胶囊会自动刷新，不再需要手动点一下才更新
    return ListenableBuilder(
      listenable: Listenable.merge([
        usbAudioStatusNotifier,
        usbExclusivePlaybackStateNotifier,
        usbAudioPreferences.performanceModeNotifier,
      ]),
      builder: (context, child) {
        final l10n = AppLocalizations.of(context);
        final status = usbAudioStatusNotifier.value;
        final exclusive = usbExclusivePlaybackStateNotifier.value;
        final outputRate = formatOutputSampleRate(status, l10n);
        final outputName = _shortOutputName(status, l10n);
        final bitDepth = _bitDepthLabel(status, l10n);
        final chipColor = _chipColor(color);
        final dotColor = _outputDotColor(status, exclusive);

        return Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                tryVibrate();
                showAudioOutputSheet(context, song);
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withAlpha(62)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(34),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulseDot(color: dotColor),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        '$outputRate  |  $bitDepth  |  $outputName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color.withAlpha(232),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Icon(
                      Icons.tune_rounded,
                      size: 17,
                      color: color.withAlpha(214),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showAudioOutputSheet(
  BuildContext context,
  MyAudioMetadata? song,
) async {
  await usbAudioService.refreshStatus();
  if (!context.mounted) return;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: _barrierColor(),
    backgroundColor: Colors.transparent,
    builder: (context) => RepaintBoundary(child: _AudioOutputSheet(song: song)),
  );
}

Future<void> showUsbAudioDetectedSheet(
  BuildContext context,
  UsbAudioStatus status,
  MyAudioMetadata? song,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: _barrierColor(),
    backgroundColor: Colors.transparent,
    builder: (context) => RepaintBoundary(
      child: _UsbAudioDetectedSheet(
        parentContext: context,
        initialStatus: status,
        song: song,
      ),
    ),
  );
}

class _UsbAudioDetectedSheet extends StatefulWidget {
  final BuildContext parentContext;
  final UsbAudioStatus initialStatus;
  final MyAudioMetadata? song;

  const _UsbAudioDetectedSheet({
    required this.parentContext,
    required this.initialStatus,
    required this.song,
  });

  @override
  State<_UsbAudioDetectedSheet> createState() => _UsbAudioDetectedSheetState();
}

class _UsbAudioDetectedSheetState extends State<_UsbAudioDetectedSheet> {
  bool _applying = false;
  late UsbAudioStatus _status = widget.initialStatus;

  Future<void> _enableExclusive() async {
    setState(() {
      _applying = true;
    });

    final nextStatus = await applyExclusiveOutputForSong(_status, widget.song);
    if (!mounted) return;

    setState(() {
      _status = nextStatus;
      _applying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final foreground = lyricsPageForegroundColor.value;
    final highlight = lyricsPageHighlightTextColor.value;
    final background = _panelBackgroundColor(foreground);
    final surface = _panelSurfaceColor(background, foreground);
    final border = foreground.withAlpha(28);
    final muted = foreground.withAlpha(150);
    final canRequestExclusive =
        _status.supported &&
        _status.androidSdk >= 34 &&
        _activeUsbDevice(_status)?.supportsBitPerfectMixer == true;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: foreground.withAlpha(45),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _OutputGlyph(active: true, accent: highlight),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.usbDacDetected,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _exclusiveStatusLabel(_status, l10n),
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SignalSection(
                title: l10n.deviceLabel,
                accent: highlight,
                foreground: foreground,
                muted: muted,
                surface: surface,
                border: border,
                rows: [
                  _InfoRow(l10n.nameLabel, _shortOutputName(_status, l10n)),
                  _InfoRow(l10n.outputSampleRate, formatOutputSampleRate(_status, l10n)),
                  _InfoRow(l10n.supportedSampleRate, _supportedRatesLabel(_status, l10n)),
                  _InfoRow(l10n.currentSong, formatSampleRate(widget.song?.samplerate, l10n)),
                ],
              ),
              const SizedBox(height: 12),
              _SignalSection(
                title: l10n.exclusive,
                accent: canRequestExclusive ? highlight : muted,
                foreground: foreground,
                muted: muted,
                surface: surface,
                border: border,
                rows: [
                  _InfoRow('Android', 'API ${_status.androidSdk}'),
                  _InfoRow('Bit-perfect', _bitPerfectSupportLabel(_status, l10n)),
                  _InfoRow(
                    l10n.requestSampleRate,
                    formatSampleRate(
                      preferredExclusiveSampleRate(
                        _status,
                        widget.song?.samplerate,
                      ),
                      l10n,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (widget.parentContext.mounted) {
                            showAudioOutputSheet(
                              widget.parentContext,
                              widget.song,
                            );
                          }
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: foreground,
                        side: BorderSide(color: foreground.withAlpha(90)),
                      ),
                      child: Text(l10n.viewLink),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canRequestExclusive && !_applying
                          ? _enableExclusive
                          : null,
                      icon: _applying
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: foreground,
                              ),
                            )
                          : const Icon(Icons.lock_rounded, size: 18),
                      label: Text(_applying ? l10n.requesting : l10n.enableExclusive),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioOutputSheet extends StatefulWidget {
  final MyAudioMetadata? song;

  const _AudioOutputSheet({required this.song});

  @override
  State<_AudioOutputSheet> createState() => _AudioOutputSheetState();
}

class _AudioOutputSheetState extends State<_AudioOutputSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final foreground = lyricsPageForegroundColor.value;
    final highlight = lyricsPageHighlightTextColor.value;
    final background = _panelBackgroundColor(foreground);
    final surface = _panelSurfaceColor(background, foreground);
    final border = foreground.withAlpha(28);
    final muted = foreground.withAlpha(150);

    return ValueListenableBuilder(
      valueListenable: usbAudioStatusNotifier,
      builder: (context, status, child) {
        final exclusive = usbExclusivePlaybackStateNotifier.value;
        final showPcmDepths = exclusive.active && exclusive.bitDepth != 1;
        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
          ),
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.heightOf(context) * 0.82,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: border),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: foreground.withAlpha(45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _OutputGlyph(active: status.supported, accent: highlight),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.audioOutput,
                              style: TextStyle(
                                color: foreground,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatOutputDeviceName(status, l10n),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SignalSection(
                    title: l10n.audioSource,
                    accent: highlight,
                    foreground: foreground,
                    muted: muted,
                    surface: surface,
                    border: border,
                    rows: [
                      _InfoRow(l10n.fileLabel, _sourcePathLabel(widget.song, l10n)),
                      _InfoRow(
                        l10n.inputSampleRate,
                        formatSampleRate(widget.song?.samplerate, l10n),
                      ),
                      _InfoRow(
                        l10n.format,
                        widget.song?.format?.toUpperCase() ?? l10n.unknown,
                      ),
                      _InfoRow(l10n.bitrate, formatBitrate(widget.song?.bitrate, l10n)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SignalSection(
                    title: l10n.signalOutput,
                    accent: status.supported ? highlight : muted,
                    foreground: foreground,
                    muted: muted,
                    surface: surface,
                    border: border,
                    rows: [
                      _InfoRow(l10n.outputPort, _outputPortLabel(status, l10n)),
                      _InfoRow(l10n.outputSampleRate, formatOutputSampleRate(status, l10n)),
                      _InfoRow(l10n.encoding, _outputEncodingLabel(status, l10n)),
                      if (showPcmDepths)
                        _InfoRow(
                          l10n.sourceBitDepth,
                          formatUsbBitDepth(exclusive.sourceBitDepth, l10n),
                        ),
                      if (showPcmDepths)
                        _InfoRow(
                          l10n.decodedBitDepth,
                          formatUsbBitDepth(exclusive.decodedBitDepth, l10n),
                        ),
                      if (showPcmDepths)
                        _InfoRow(
                          l10n.usbSlotBitDepth,
                          formatUsbBitDepth(exclusive.usbBitDepth, l10n),
                        ),
                      _InfoRow(
                        'Bit-perfect',
                        _bitPerfectStatusLabel(status, l10n),
                      ),
                    ],
                  ),
                  if (!status.supported) ...[
                    const SizedBox(height: 14),
                    Text(
                      l10n.noUsbDacInfo,
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignalSection extends StatelessWidget {
  final String title;
  final Color accent;
  final Color foreground;
  final Color muted;
  final Color surface;
  final Color border;
  final List<_InfoRow> rows;

  const _SignalSection({
    required this.title,
    required this.accent,
    required this.foreground,
    required this.muted,
    required this.surface,
    required this.border,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 78,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: accent.withAlpha(76),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground.withAlpha(232),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final row in rows)
                  _InfoLine(row: row, foreground: foreground, muted: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final _InfoRow row;
  final Color foreground;
  final Color muted;

  const _InfoLine({
    required this.row,
    required this.foreground,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              row.label,
              style: TextStyle(color: muted.withAlpha(150), fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground.withAlpha(222),
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputGlyph extends StatelessWidget {
  final bool active;
  final Color accent;

  const _OutputGlyph({required this.active, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: active
            ? accent.withAlpha(45)
            : lyricsPageForegroundColor.value.withAlpha(18),
        shape: BoxShape.circle,
        border: Border.all(
          color: active
              ? accent
              : lyricsPageForegroundColor.value.withAlpha(62),
        ),
      ),
      child: Icon(
        active ? Icons.usb_rounded : Icons.graphic_eq_rounded,
        color: active ? accent : lyricsPageForegroundColor.value.withAlpha(180),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  final Color color;

  const _PulseDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(140),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

/// 胶囊左侧状态指示灯颜色：独占 PCM 绿、独占 DSD 蓝、开了独占却未生效(失败)红、
/// 非独占(系统输出)白。这是状态语义灯，独立于跟随封面的主题配色。
Color _outputDotColor(UsbAudioStatus status, UsbExclusivePlaybackState exclusive) {
  final perfMode = usbAudioPreferences.performanceModeNotifier.value;
  if (perfMode && exclusive.active) {
    // DoP/Native 的 DSD 是 1-bit 流，恒位完美，走蓝
    if (exclusive.bitDepth == 1) {
      return const Color(0xFF3B82F6); // DSD 蓝
    }
    // PCM 独占：原始数字电平旁路=位完美紫，启用了数字音量=绿
    return _exclusiveBitPerfect(exclusive)
        ? const Color(0xFFAF52DE) // PCM 位完美 紫
        : const Color(0xFF34C759); // PCM 绿
  }
  // 非独占但系统 Preferred Mixer 真正以 bit-perfect 生效：单纯用 DAC 的无损系统输出。
  // 用 preferredBitPerfect 而非 preferredApplied——default behavior 只是普通重采样，不是无损，
  // 不该标黄（很多 DAC supportsBitPerfectMixer=false，系统层给不了 bit-perfect，只能靠真独占）。
  if (status.preferredBitPerfect) {
    return const Color(0xFFFFCC00); // 黄
  }
  if (perfMode && status.supported) {
    // 已开独占且连着 DAC，独占与系统无损都没生效 = 失败/回退
    return const Color(0xFFFF3B30); // 红
  }
  return Colors.white; // 非独占普通输出
}

/// 独占是否真正位完美：DSD/DoP 引擎强制旁路恒位完美；PCM 只有音量方式为
/// “原始数字电平”（旁路直通、不施加数字增益）时才位完美。
bool _exclusiveBitPerfect(UsbExclusivePlaybackState exclusive) {
  if (!exclusive.active) return false;
  if (exclusive.bitDepth == 1) return true;
  if (exclusive.bitPerfect != null) return exclusive.bitPerfect!;
  return !exclusive.digitalVolumeActive;
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);
}

String _shortOutputName(UsbAudioStatus status, AppLocalizations l10n) {
  final exclusive = usbExclusivePlaybackStateNotifier.value;
  if (exclusive.active) {
    return 'USB';
  }

  if (!status.supported) {
    return formatOutputDeviceName(status, l10n);
  }
  final device = _activeUsbDevice(status);
  if (device != null) return device.name;
  return status.outputDeviceName ?? 'USB DAC';
}

UsbAudioDevice? _activeUsbDevice(UsbAudioStatus status) {
  for (final device in status.devices) {
    if (device.id == status.bestAvailableDeviceId) {
      return device;
    }
  }
  return null;
}

String _supportedRatesLabel(UsbAudioStatus status, AppLocalizations l10n) {
  final device = _activeUsbDevice(status);
  final rates = device?.supportedMixerSampleRates.isNotEmpty == true
      ? device!.supportedMixerSampleRates
      : device?.sampleRates ?? const <int>[];
  if (rates.isEmpty) return l10n.unknown;
  return rates.map((rate) => formatSampleRate(rate, l10n)).join(' / ');
}

String _bitPerfectSupportLabel(UsbAudioStatus status, AppLocalizations l10n) {
  if (!status.supported) return l10n.unavailable;
  if (status.androidSdk < 34) return l10n.needAndroid14;
  final device = _activeUsbDevice(status);
  if (device?.supportsBitPerfectMixer == true) {
    return status.preferredBitPerfect ? l10n.requested : l10n.available;
  }
  return l10n.deviceNotDeclared;
}

String _exclusiveStatusLabel(UsbAudioStatus status, AppLocalizations l10n) {
  if (!status.supported) return l10n.noUsbAudioDevice;
  if (status.androidSdk < 34) return l10n.systemNoExclusive;
  if (status.preferredBitPerfect && status.preferredSampleRate != null) {
    return l10n.requestedExclusive;
  }
  if (_activeUsbDevice(status)?.supportsBitPerfectMixer == true) {
    return l10n.canEnableExclusive;
  }
  return l10n.connectedNotConfirmed;
}

String _bitDepthLabel(UsbAudioStatus status, AppLocalizations l10n) {
  final exclusive = usbExclusivePlaybackStateNotifier.value;
  if (exclusive.active && exclusive.bitDepth != null) {
    // DoP 激活时 bitDepth=1（DSD 是 1-bit 流）
    if (exclusive.bitDepth == 1) return '1 bit';
    return formatUsbBitDepth(
      exclusive.decodedBitDepth ?? exclusive.bitDepth,
      l10n,
    );
  }

  final encoding = status.preferredEncoding ?? status.outputEncoding;
  if (encoding == 'pcm_float') return '32 bits';
  if (encoding == 'pcm_32bit') return '32 bits';
  if (encoding == 'pcm_24bit_packed') return '24 bits';
  if (encoding == 'pcm_16bit') return '16 bits';
  return l10n.unknown;
}

String formatUsbBitDepth(int? bitDepth, AppLocalizations l10n) {
  return bitDepth == null ? l10n.unknown : '$bitDepth bits';
}

String _outputEncodingLabel(UsbAudioStatus status, AppLocalizations l10n) {
  final exclusive = usbExclusivePlaybackStateNotifier.value;
  // 独占直驱 DSD 时按 DoP/Native 呈现，而非 PCM（bitDepth=1 是 DSD 1-bit 流，
  // format 形如 "dsf(DoP)"/"dff(Native)"）
  if (exclusive.active && exclusive.bitDepth == 1) {
    final mode = (exclusive.format ?? '').contains('Native') ? 'Native' : 'DoP';
    return 'DSD ($mode)';
  }
  final encoding = status.preferredEncoding ?? status.outputEncoding;
  if (encoding == null) return l10n.pcmSystemDefault;
  final bitDepth = _bitDepthLabel(status, l10n);
  return bitDepth == l10n.unknown ? encoding : 'PCM / $bitDepth';
}

String _bitPerfectStatusLabel(UsbAudioStatus status, AppLocalizations l10n) {
  final exclusive = usbExclusivePlaybackStateNotifier.value;
  // 独占直驱时反映独占真实位完美状态；非独占回退系统共享链路偏好
  if (exclusive.active) {
    var processing = exclusive.hardwareVolumeActive
        ? l10n.volumeControlDac
        : exclusive.digitalVolumeActive
        ? l10n.volumeControlDigital
        : l10n.volumeControlRaw;
    if (exclusive.hardwareVolumeFrozen) {
      processing = '$processing (${l10n.hardwareVolumeFrozen})';
    } else if (exclusive.hardwareVolumeSyncPending) {
      processing = '$processing (${l10n.hardwareVolumeSyncPending})';
    } else if (exclusive.hardwareVolumeActive &&
        exclusive.hardwareVolumeUnverified) {
      processing = '$processing (${l10n.hardwareVolumeUnverified})';
    }
    final bitDepthConverted = exclusive.sourceBitDepth != null &&
        exclusive.decodedBitDepth != null &&
        exclusive.usbBitDepth != null &&
        (exclusive.sourceBitDepth != exclusive.decodedBitDepth ||
            exclusive.decodedBitDepth != exclusive.usbBitDepth);
    if (!exclusive.digitalVolumeActive && bitDepthConverted) {
      processing = '$processing · ${l10n.bitDepthConverted}';
    }
    if (exclusive.replayGainMilliDb != 0) {
      if (exclusive.hardwareVolumeActive || exclusive.digitalVolumeActive) {
        final gain = (exclusive.replayGainMilliDb / 1000)
            .toStringAsFixed(3)
            .replaceFirst(RegExp(r'\.?0+$'), '');
        return l10n.audioProcessingWithReplayGain(processing, gain);
      }
      return l10n.audioProcessingWithReplayGainNotApplied(processing);
    }
    return processing;
  }
  return status.preferredBitPerfect
      ? l10n.requested
      : status.supported
      ? l10n.notEnabled
      : l10n.unavailable;
}

String _outputPortLabel(UsbAudioStatus status, AppLocalizations l10n) {
  return formatOutputPortLabel(status, l10n);
}

String _sourcePathLabel(MyAudioMetadata? song, AppLocalizations l10n) {
  return formatSourceFileName(song?.path ?? song?.cachePath, l10n);
}

Color _chipColor(Color foreground) {
  final background = _panelBackgroundColor(foreground);
  return Color.alphaBlend(foreground.withAlpha(18), background.withAlpha(220));
}

Color _panelBackgroundColor(Color foreground) {
  final tint = _panelTintColor();
  final lightForeground = foreground.computeLuminance() > 0.45;
  // 明暗基底从主题色（封面/歌词页背景）派生：保证足够对比的同时带上主题色调，
  // 不再用中性灰硬编码
  final neutral = lightForeground
      ? Color.lerp(tint, Colors.black, 0.82)!
      : Color.lerp(tint, Colors.white, 0.86)!;
  return Color.alphaBlend(tint.withAlpha(lightForeground ? 96 : 136), neutral);
}

Color _panelSurfaceColor(Color background, Color foreground) {
  final lightForeground = foreground.computeLuminance() > 0.45;
  return Color.alphaBlend(
    foreground.withAlpha(lightForeground ? 18 : 14),
    background,
  );
}

Color _barrierColor() {
  final tint = _panelTintColor();
  return Color.alphaBlend(tint.withAlpha(30), Colors.black.withAlpha(70));
}

Color _panelTintColor() {
  final pageBackground = lyricsPageBackgroundColor.value;
  return pageBackground == Colors.transparent
      ? currentCoverArtColor
      : pageBackground;
}
