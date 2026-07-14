import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/widgets/audio_output_panel.dart';
import 'package:sylvakru/base/widgets/my_sheet.dart';
import 'package:sylvakru/base/widgets/my_switch.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/settings_layer.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';

part '../portrait_view/pages/audio_output_settings_page.dart';
part '../landscape_view/panels/audio_output_settings_panel.dart';

final audioOutputVisibleNotifier = ValueNotifier(true);

enum AudioOutputSettingsPageKind {
  overview,
  fixedSampleRate,
  dsdMode,
  replayGain,
}

String _transportHealthLabel(UsbTransportHealth health, AppLocalizations l10n) {
  return switch (health) {
    UsbTransportHealth.idle => l10n.transportIdle,
    UsbTransportHealth.paused => l10n.transportPaused,
    UsbTransportHealth.stable => l10n.transportStable,
    UsbTransportHealth.low => l10n.transportLow,
    UsbTransportHealth.underrun => l10n.transportUnderrun,
  };
}

Color _transportHealthAccent(UsbTransportHealth health) {
  return switch (health) {
    UsbTransportHealth.stable => const Color(0xFF50D890),
    UsbTransportHealth.low => const Color(0xFFFFB454),
    UsbTransportHealth.underrun => const Color(0xFFFF6B6B),
    UsbTransportHealth.idle ||
    UsbTransportHealth.paused => highlightTextColor.value,
  };
}

class AudioOutputSettingsLayer extends StatefulWidget {
  final AudioOutputSettingsPageKind pageKind;

  const AudioOutputSettingsLayer({
    super.key,
    this.pageKind = AudioOutputSettingsPageKind.overview,
  });

  @override
  State<AudioOutputSettingsLayer> createState() =>
      _AudioOutputSettingsLayerState();
}

class _AudioOutputSettingsLayerState extends State<AudioOutputSettingsLayer> {
  UsbExclusiveProbeResult? _exclusiveProbeResult;
  bool _probingExclusive = false;
  bool _refreshingStatus = false;
  bool _generatingReport = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    if (isTooNarrow(context)) {
      return pageView(context);
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        settingsVisibleNotifier,
        audioOutputVisibleNotifier,
      ]),
      builder: (context, _) {
        // overview 在 audioOutputVisibleNotifier 为真时显示；固定采样率/DSD 深层页压栈后
        // 该 notifier 置假，overview 隐藏、深层页显示，避免横屏底层残留。
        final visible =
            widget.pageKind == AudioOutputSettingsPageKind.overview
            ? !settingsVisibleNotifier.value && audioOutputVisibleNotifier.value
            : !settingsVisibleNotifier.value &&
                  !audioOutputVisibleNotifier.value;
        return Opacity(opacity: visible ? 1 : 0, child: panelView(context));
      },
    );
  }

  String get _title {
    return switch (widget.pageKind) {
      AudioOutputSettingsPageKind.overview => _l10n.usbOutputSettings,
      AudioOutputSettingsPageKind.fixedSampleRate => _l10n.fixedSampleRateOutput,
      AudioOutputSettingsPageKind.dsdMode => _l10n.dsdMode,
      AudioOutputSettingsPageKind.replayGain => _l10n.replayGain,
    };
  }

  Widget _content() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ValueListenableBuilder(
          valueListenable: mainPageThemeNotifier,
          builder: (context, value, child) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                switch (widget.pageKind) {
                  AudioOutputSettingsPageKind.overview => _overview(),
                  AudioOutputSettingsPageKind.fixedSampleRate =>
                    _fixedSampleRate(),
                  AudioOutputSettingsPageKind.dsdMode => _dsdMode(),
                  AudioOutputSettingsPageKind.replayGain => _replayGain(),
                },
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _overview() {
    final prefs = usbAudioPreferences;
    return ValueListenableBuilder<UsbAudioStatus>(
      valueListenable: usbAudioStatusNotifier,
      builder: (context, status, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _deviceStatusCard(status),
            const SizedBox(height: 12),
            _transportStatusCard(status),
            const SizedBox(height: 18),
            _sectionTitle(_l10n.outputFormat),
            _settingsCard(
              children: [
                _formatSummaryTile(status),
                _navTile(
                  title: _l10n.fixedSampleRateOutput,
                  value: prefs.fixedSampleRateEnabledNotifier.value
                      ? formatSampleRate(prefs.fixedSampleRateNotifier.value, _l10n)
                      : _l10n.usbOff,
                  onTap: () {
                    layersManager.pushDetail(
                      'settings',
                      'usb_fixed_sample_rate',
                    );
                  },
                ),
                _navTile(
                  title: _l10n.dsdMode,
                  value: _dsdModeLabel(prefs.dsdModeNotifier.value),
                  onTap: () {
                    layersManager.pushDetail('settings', 'usb_dsd_mode');
                  },
                ),
                _choiceTile<UsbBitDepthMode>(
                  title: _l10n.pcmBitDepth,
                  notifier: prefs.bitDepthModeNotifier,
                  values: UsbBitDepthMode.values,
                  label: _bitDepthModeLabel,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle(_l10n.backgroundStability),
            _settingsCard(
              children: [
                _noticeTile(
                  icon: Icons.battery_alert_rounded,
                  title: _l10n.suggestDisableBatteryOpt,
                  subtitle: _l10n.suggestDisableBatteryOptDesc,
                  actionLabel: _l10n.openSettings,
                  onTap: openAppSettings,
                ),
                _switchTile(
                  title: _l10n.usbExclusiveMode,
                  subtitle: _l10n.usbExclusiveModeDesc,
                  notifier: prefs.performanceModeNotifier,
                ),
                _switchTile(
                  title: _l10n.keepBackgroundActive,
                  subtitle: _l10n.keepBackgroundActiveDesc,
                  notifier: prefs.keepAliveInBackgroundNotifier,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle(_l10n.transportBuffer),
            _settingsCard(
              children: [
                _bufferSlider(
                  title: _l10n.foregroundBuffer,
                  notifier: prefs.foregroundBufferMsNotifier,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  onChanged: (value) =>
                      _applyExclusiveBufferIfActive(foregroundBufferMs: value),
                ),
                _bufferSlider(
                  title: _l10n.backgroundBuffer,
                  notifier: prefs.backgroundBufferMsNotifier,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  onChanged: (value) =>
                      _applyExclusiveBufferIfActive(backgroundBufferMs: value),
                ),
                _hintTile(_l10n.backgroundBufferDesc),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle(_l10n.volumeSection),
            _settingsCard(
              children: [
                _choiceTile<UsbVolumeControlMode>(
                  title: _l10n.volumeControl,
                  notifier: prefs.volumeControlModeNotifier,
                  values: UsbVolumeControlMode.values,
                  label: _volumeControlLabel,
                ),
                ValueListenableBuilder<ReplayGainMode>(
                  valueListenable: prefs.replayGainModeNotifier,
                  builder: (context, mode, _) {
                    return _navTile(
                      title: _l10n.replayGain,
                      value: _replayGainLabel(mode),
                      onTap: () {
                        layersManager.pushDetail('settings', 'usb_replay_gain');
                      },
                    );
                  },
                ),
                _choiceTile<int>(
                  title: _l10n.dsdGainCompensation,
                  notifier: prefs.dsdGainCompensationNotifier,
                  values: const [-12, -9, -6, -3, 0, 3, 6],
                  label: (value) => '$value dB',
                ),
                _mediaVolumeTile(),
                _switchTile(
                  title: _l10n.volumeSmoothHandoff,
                  subtitle: _l10n.volumeSmoothHandoffDesc,
                  notifier: prefs.volumeSmoothHandoffNotifier,
                ),
              ],
            ),
            ValueListenableBuilder<UsbVolumeControlMode>(
              valueListenable: prefs.volumeControlModeNotifier,
              builder: (context, mode, _) {
                if (mode != UsbVolumeControlMode.auto &&
                    mode != UsbVolumeControlMode.dac) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                  child: Text(
                    _l10n.volumeControlDacFallbackHint,
                    style: TextStyle(
                      color: textColor.value.withAlpha(130),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            _sectionTitle(_l10n.compatibility),
            _settingsCard(
              children: [
                _switchTile(
                  title: _l10n.releaseUsbBandwidth,
                  subtitle: _l10n.releaseUsbBandwidthDesc,
                  notifier: prefs.releaseUsbBandwidthAfterPlaybackNotifier,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionTitle(_l10n.supportSection),
            _settingsCard(
              children: [
                _actionTile(
                  icon: Icons.fact_check_rounded,
                  title: _l10n.usbExclusiveDiagnostics,
                  subtitle: _exclusiveProbeSummary(),
                  actionLabel: _probingExclusive ? _l10n.detecting : _l10n.startDetection,
                  onTap: _probingExclusive ? null : _runExclusiveProbe,
                ),
                _actionTile(
                  icon: Icons.assignment_rounded,
                  title: _l10n.generateDiagnosticsReport,
                  subtitle: _l10n.generateDiagnosticsReportDesc,
                  actionLabel: _generatingReport ? _l10n.generating : _l10n.generateReport,
                  onTap: _generatingReport ? null : _generateDiagnosticsReport,
                ),
                _actionTile(
                  icon: Icons.tune_rounded,
                  title: _l10n.importQuirkConfig,
                  subtitle: _l10n.importQuirkConfigDesc,
                  actionLabel: _l10n.importAction,
                  onTap: _showImportQuirkSheet,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _deviceStatusCard(UsbAudioStatus status) {
    return ValueListenableBuilder<UsbExclusivePlaybackState>(
      valueListenable: usbExclusivePlaybackStateNotifier,
      builder: (context, exclusive, _) {
        final device = _activeUsbDevice(status);
        final supported = status.supported;
        final accent = supported ? const Color(0xFF50D890) : textColor.value;
        final foreground = textColor.value;
        final background = Color.alphaBlend(
          accent.withAlpha(mainPageThemeNotifier.value == .dark ? 34 : 20),
          menuColor.value,
        );
        final manufacturer = status.manufacturerName?.trim();
        final product = status.productName?.trim();
        final title = supported
            ? manufacturer?.isNotEmpty == true
                  ? manufacturer!
                  : device?.name ?? 'USB DAC'
            : _l10n.unrecognizedUsbDevice;
        final subtitle =
            supported && product?.isNotEmpty == true && product != title
            ? product
            : null;
        final statusLabel = supported ? _l10n.connected : _l10n.notConnected;
        final linkLabel = supported
            ? (exclusive.active ? _l10n.exclusivePlayback : _l10n.running)
            : _l10n.awaitingConnection;
        final dsdMode = exclusive.format?.contains('(Native)') == true
            ? 'Native'
            : 'DoP';
        final formatLabel =
            '${exclusive.active && exclusive.bitDepth == 1 ? dsdMode : 'PCM'} '
                    '${formatOutputSampleRate(status, _l10n)}'
                .replaceAll(_l10n.unknown, _l10n.systemDefault);
        final depthLabel = exclusive.active && exclusive.bitDepth != null
            ? '${exclusive.bitDepth}-bit'
            : _compactDepthLabel(status);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withAlpha(70)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.usb_rounded, color: foreground.withAlpha(170)),
                    const SizedBox(width: 10),
                    Text(
                      _l10n.usbExclusiveLabel,
                      style: TextStyle(
                        color: foreground.withAlpha(150),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: supported ? accent : foreground.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: foreground.withAlpha(165),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _refreshingStatus
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: iconColor.value,
                            ),
                          )
                        : IconButton(
                            tooltip: _l10n.refreshUsbStatus,
                            onPressed: _refreshStatus,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 24,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground.withAlpha(165),
                      fontSize: 17,
                      height: 1.05,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: supported ? accent : foreground.withAlpha(100),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _l10n.outputLinkLabel,
                      style: TextStyle(
                        color: foreground.withAlpha(135),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      linkLabel,
                      style: TextStyle(
                        color: foreground.withAlpha(190),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _metricColumn(_l10n.formatLabel, formatLabel),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metricColumn(_l10n.depthLabel, depthLabel),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _metricColumn(
                        _l10n.usbIdLabel,
                        _usbIdLabel(status),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _transportStatusCard(UsbAudioStatus status) {
    return ValueListenableBuilder<int>(
      valueListenable: usbAudioPreferences.foregroundBufferMsNotifier,
      builder: (context, foregroundTargetMs, _) {
        return ValueListenableBuilder<UsbExclusivePlaybackState>(
          valueListenable: usbExclusivePlaybackStateNotifier,
          builder: (context, exclusive, _) {
            return ValueListenableBuilder<UsbTransportTelemetry>(
              valueListenable: usbTransportTelemetryNotifier,
              builder: (context, telemetry, _) {
                final active = exclusive.active || telemetry.active;
                final targetMs = _currentExclusiveTargetBufferMs(
                  foregroundTargetMs: foregroundTargetMs,
                  backgroundTargetMs:
                      usbAudioPreferences.backgroundBufferMsNotifier.value,
                );
                final levelMs = telemetry.active
                    ? telemetry.bufferLevel.inMilliseconds
                    : 0;
                final minimumMs = telemetry.minimumBufferLevel?.inMilliseconds;
                final clampedLevel = levelMs.clamp(0, targetMs);
                final progress = targetMs <= 0 ? 0.0 : clampedLevel / targetMs;
                final health = telemetry.health(
                  playing: exclusive.playing,
                  targetMs: targetMs,
                );
                final accent = _transportHealthAccent(health);
                final foreground = textColor.value;
                final background = Color.alphaBlend(
                  accent.withAlpha(
                    mainPageThemeNotifier.value == .dark ? 36 : 24,
                  ),
                  menuColor.value,
                );

                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withAlpha(60)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _l10n.transportStatus,
                                style: TextStyle(
                                  color: foreground,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              _transportHealthLabel(health, _l10n),
                              style: TextStyle(
                                color: active
                                    ? accent
                                    : foreground.withAlpha(170),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              flex: 4,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  '$levelMs ms',
                                  style: TextStyle(
                                    color: foreground,
                                    fontSize: 34,
                                    height: 0.95,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Text(
                                  _l10n.bufferLevel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: foreground.withAlpha(145),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: foreground.withAlpha(28),
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                active ? _l10n.targetMs(targetMs) : _l10n.buildTargetOnPlay,
                                style: TextStyle(
                                  color: foreground.withAlpha(135),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              active && minimumMs != null
                                  ? _l10n.minimumMs(minimumMs)
                                  : _l10n.minimumNone,
                              style: TextStyle(
                                color: foreground.withAlpha(135),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _fixedSampleRate() {
    final prefs = usbAudioPreferences;
    return Column(
      children: [
        _settingsCard(
          children: [
            _switchTile(
              title: _l10n.enableFixedSampleRate,
              subtitle: _l10n.enableFixedSampleRateDesc,
              notifier: prefs.fixedSampleRateEnabledNotifier,
            ),
            for (final rate in UsbAudioPreferences.sampleRates)
              ValueListenableBuilder<int?>(
                valueListenable: prefs.fixedSampleRateNotifier,
                builder: (context, selectedRate, _) {
                  return _radioTile<int>(
                    title: formatSampleRate(rate, _l10n),
                    value: rate,
                    groupValue: selectedRate,
                    onTap: () {
                      prefs.fixedSampleRateNotifier.value = rate;
                      setting.save();
                    },
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _dsdMode() {
    final prefs = usbAudioPreferences;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(_l10n.dsdOutputStrategy),
        _settingsCard(
          children: [
            for (final mode in UsbDsdMode.values)
              ValueListenableBuilder<UsbDsdMode>(
                valueListenable: prefs.dsdModeNotifier,
                builder: (context, selectedMode, _) {
                  return _radioTile<UsbDsdMode>(
                    title: _dsdModeLabel(mode),
                    subtitle: _dsdModeHint(mode),
                    value: mode,
                    groupValue: selectedMode,
                    onTap: () {
                      prefs.dsdModeNotifier.value = mode;
                      setting.save();
                    },
                  );
                },
              ),
          ],
        ),
        ValueListenableBuilder<UsbDsdMode>(
          valueListenable: prefs.dsdModeNotifier,
          builder: (context, mode, _) {
            if (mode != UsbDsdMode.pcm) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 18),
                _sectionTitle(_l10n.dsdToPcmRates),
                _settingsCard(
                  children: [
                    _dsdPcmRateTile('DSD64', prefs.dsd64PcmRateNotifier),
                    _dsdPcmRateTile('DSD128', prefs.dsd128PcmRateNotifier),
                    _dsdPcmRateTile('DSD256', prefs.dsd256PcmRateNotifier),
                    _dsdPcmRateTile('DSD512', prefs.dsd512PcmRateNotifier),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _replayGain() {
    final prefs = usbAudioPreferences;
    return _settingsCard(
      children: [
        for (final mode in ReplayGainMode.values)
          ValueListenableBuilder<ReplayGainMode>(
            valueListenable: prefs.replayGainModeNotifier,
            builder: (context, selectedMode, _) {
              return _radioTile<ReplayGainMode>(
                title: _replayGainLabel(mode),
                subtitle: _replayGainHint(mode),
                value: mode,
                groupValue: selectedMode,
                onTap: () {
                  prefs.replayGainModeNotifier.value = mode;
                  setting.save();
                },
              );
            },
          ),
      ],
    );
  }

  Widget _dsdPcmRateTile(String title, ValueNotifier<int> notifier) {
    return _choiceTile<int>(
      title: title,
      notifier: notifier,
      values: UsbAudioPreferences.sampleRates,
      label: (value) => '${formatSampleRate(value, _l10n)} PCM',
    );
  }

  Widget _settingsCard({required List<Widget> children}) {
    // 用同色同圆角的 Material 承载，让内部 ListTile 的水波纹画在卡片本身上，
    // 避免带色 DecoratedBox 盖住 ink 触发框架断言。
    return Material(
      color: menuColor.value,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) _divider(),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: textColor.value.withAlpha(150),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required ValueNotifier<bool> notifier,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: SizedBox(
        width: 52,
        child: MySwitch(
          valueNotifier: notifier,
          onToggleCallBack: setting.save,
        ),
      ),
    );
  }

  Widget _navTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: textColor.value.withAlpha(150))),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _formatSummaryTile(UsbAudioStatus status) {
    return ValueListenableBuilder<MyAudioMetadata?>(
      valueListenable: currentSongNotifier,
      builder: (context, song, _) {
        return ValueListenableBuilder<UsbExclusivePlaybackState>(
          valueListenable: usbExclusivePlaybackStateNotifier,
          builder: (context, exclusive, _) {
            final channel = _channelCountLabel(status);
            // DoP 独占时端点收到的是封装 DSD 的 24-bit PCM 帧（帧率 = DSD 速率 ÷ 16），
            // 不能按源文件的 DSD 速率 / 1-bit 展示；Native 独占时端点收到的就是
            // 原始 1-bit DSD 流，直接按 DSD 速率展示
            final dopActive =
                exclusive.active &&
                exclusive.sampleRate != null &&
                (exclusive.format?.contains('(DoP)') ?? false);
            final nativeActive =
                exclusive.active &&
                exclusive.sampleRate != null &&
                (exclusive.format?.contains('(Native)') ?? false);
            final sourceDepth = song?.isDsd == true
                ? '1-bit'
                : formatUsbBitDepth(
                    exclusive.sourceBitDepth,
                    _l10n,
                  ).replaceAll(' bits', '-bit');
            final endpointDepth = formatUsbBitDepth(
              exclusive.usbBitDepth,
              _l10n,
            ).replaceAll(' bits', '-bit');
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _formatMetricRow(_l10n.sourceFile, [
                    _sourceFormatLabel(song),
                    formatSampleRate(song?.samplerate, _l10n),
                    channel,
                    sourceDepth,
                  ]),
                  const SizedBox(height: 24),
                  _formatMetricRow(_l10n.dacEndpoint, [
                    nativeActive ? 'DSD' : (dopActive ? 'DoP' : 'PCM'),
                    nativeActive
                        ? formatSampleRate(exclusive.sampleRate, _l10n)
                        : dopActive
                        ? formatSampleRate(exclusive.sampleRate! ~/ 16, _l10n)
                        : formatOutputSampleRate(status, _l10n),
                    channel,
                    nativeActive
                        ? '1-bit'
                        : dopActive
                        ? '24-bit'
                        : endpointDepth,
                  ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _formatMetricRow(String label, List<String> values) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor.value.withAlpha(145),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < values.length; index++) ...[
              Expanded(
                // DSD128 / 352.8 kHz 之类的长值超出列宽时整体缩小，不省略截断
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    values[index],
                    maxLines: 1,
                    style: TextStyle(
                      color: textColor.value.withAlpha(220),
                      fontSize: 22,
                      height: 1.05,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (index != values.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      ],
    );
  }

  Widget _mediaVolumeTile() {
    return ValueListenableBuilder<double>(
      valueListenable: usbExclusiveVolumeNotifier,
      builder: (context, volume, _) {
        final percent = (volume.clamp(0.0, 1.0) * 100).round();
        final sliderValue = volume.clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _l10n.mediaVolume,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: textColor.value.withAlpha(180),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: _sliderThemeData(context),
                child: Slider(
                  value: sliderValue,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  label: '$percent%',
                  onChanged: (next) {
                    usbExclusiveVolumeNotifier.value = next;
                    _setUsbExclusiveVolumeIfReady(next);
                  },
                  onChangeEnd: (_) => setting.save(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setUsbExclusiveVolumeIfReady(double volume) {
    try {
      audioHandler.setUsbExclusiveVolume(volume);
    } on Error catch (error) {
      if (!error.toString().contains('LateInitializationError')) rethrow;
    }
  }

  Widget _noticeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: _iconBox(icon, const Color(0xFFFF6868), compact: true),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: highlightTextColor.value),
        child: Text(actionLabel),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: _iconBox(icon, highlightTextColor.value, compact: true),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: highlightTextColor.value),
        child: Text(actionLabel),
      ),
    );
  }

  Widget _hintTile(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Text(
        text,
        style: TextStyle(color: textColor.value.withAlpha(130), fontSize: 12),
      ),
    );
  }

  Widget _bufferSlider({
    required String title,
    required ValueNotifier<int> notifier,
    required double min,
    required double max,
    required int divisions,
    ValueChanged<int>? onChanged,
  }) {
    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, value, _) {
        final sliderValue = value.toDouble().clamp(min, max);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${sliderValue.round()} ms',
                    style: TextStyle(
                      color: textColor.value.withAlpha(180),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: _sliderThemeData(context),
                child: Slider(
                  value: sliderValue,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: '${sliderValue.round()} ms',
                  onChanged: (next) {
                    final rounded = next.round();
                    notifier.value = rounded;
                    onChanged?.call(rounded);
                  },
                  onChangeEnd: (_) => setting.save(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  SliderThemeData _sliderThemeData(BuildContext context) {
    final accent = iconColor.value;
    return SliderTheme.of(context).copyWith(
      activeTrackColor: accent,
      inactiveTrackColor: accent.withAlpha(40),
      thumbColor: accent,
      overlayColor: accent.withAlpha(30),
      valueIndicatorColor: accent,
      valueIndicatorTextStyle: TextStyle(color: menuColor.value),
    );
  }

  Widget _radioTile<T>({
    required String title,
    String? subtitle,
    required T value,
    required T? groupValue,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: groupValue == value
          ? Icon(Icons.check_rounded, color: highlightTextColor.value)
          : Icon(Icons.circle_outlined, color: textColor.value.withAlpha(120)),
      onTap: onTap,
    );
  }

  Widget _choiceTile<T>({
    required String title,
    required ValueNotifier<T> notifier,
    required List<T> values,
    required String Function(T value) label,
  }) {
    return ValueListenableBuilder<T>(
      valueListenable: notifier,
      builder: (context, value, _) {
        return ListTile(
          title: Text(title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label(value),
                style: TextStyle(color: textColor.value.withAlpha(150)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          onTap: () => _showChoiceSheet<T>(
            title: title,
            notifier: notifier,
            values: values,
            label: label,
          ),
        );
      },
    );
  }

  void _showChoiceSheet<T>({
    required String title,
    required ValueNotifier<T> notifier,
    required List<T> values,
    required String Function(T value) label,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return MySheet(
          ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
            children: [
              ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              for (final value in values)
                ValueListenableBuilder<T>(
                  valueListenable: notifier,
                  builder: (context, currentValue, _) {
                    return ListTile(
                      title: Text(label(value)),
                      trailing: currentValue == value
                          ? Icon(
                              Icons.check_rounded,
                              color: highlightTextColor.value,
                            )
                          : null,
                      onTap: () {
                        notifier.value = value;
                        setting.save();
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconBox(IconData icon, Color color, {bool compact = false}) {
    final size = compact ? 34.0 : 42.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(compact ? 10 : 13),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Icon(icon, color: color, size: compact ? 18 : 22),
    );
  }

  Widget _metricColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor.value.withAlpha(125),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: textColor.value.withAlpha(215),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: textColor.value.withAlpha(22),
    );
  }

  void _applyExclusiveBufferIfActive({
    int? foregroundBufferMs,
    int? backgroundBufferMs,
  }) {
    final exclusive = usbExclusivePlaybackStateNotifier.value;
    if (!exclusive.active) return;

    final targetBufferMs = _currentExclusiveTargetBufferMs(
      foregroundTargetMs:
          foregroundBufferMs ??
          usbAudioPreferences.foregroundBufferMsNotifier.value,
      backgroundTargetMs:
          backgroundBufferMs ??
          usbAudioPreferences.backgroundBufferMsNotifier.value,
    );
    unawaited(usbAudioService.setExclusiveTargetBufferMs(targetBufferMs));
  }

  int _currentExclusiveTargetBufferMs({
    required int foregroundTargetMs,
    required int backgroundTargetMs,
  }) {
    if (_usesBackgroundExclusiveBuffer()) {
      return backgroundTargetMs;
    }
    return foregroundTargetMs;
  }

  bool _usesBackgroundExclusiveBuffer() {
    if (!usbAudioPreferences.keepAliveInBackgroundNotifier.value) {
      return false;
    }
    return switch (WidgetsBinding.instance.lifecycleState) {
      AppLifecycleState.resumed || null => false,
      AppLifecycleState.inactive ||
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => true,
    };
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _refreshingStatus = true;
    });
    await usbAudioService.refreshStatus();
    if (!mounted) return;
    setState(() {
      _refreshingStatus = false;
    });
  }

  Future<void> _runExclusiveProbe() async {
    setState(() {
      _probingExclusive = true;
    });

    final result = await usbAudioService.probeExclusiveAccess();
    if (!mounted) return;

    setState(() {
      _exclusiveProbeResult = result;
      _probingExclusive = false;
    });
  }

  Future<void> _generateDiagnosticsReport() async {
    setState(() {
      _generatingReport = true;
    });

    String report;
    try {
      report = await usbAudioService.getDiagnosticsReport();
    } catch (error) {
      report = 'Sylvakru USB Diagnostics Report v1\n\nGeneration failed: $error';
    }

    if (!mounted) return;
    setState(() {
      _generatingReport = false;
    });
    _showDiagnosticsReportSheet(report);
  }

  void _showDiagnosticsReportSheet(String report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheetContext) {
        return MySheet(
          height: MediaQuery.heightOf(sheetContext) * 0.85,
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  _l10n.usbDiagnosticsReport,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _l10n.usbDiagnosticsReportPrivacy,
                  style: TextStyle(
                    color: textColor.value.withAlpha(150),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: textColor.value.withAlpha(12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        report,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyReport(report),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor.value,
                          side: BorderSide(color: textColor.value.withAlpha(60)),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(_l10n.copyToClipboard),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _exportReport(report),
                        style: FilledButton.styleFrom(
                          backgroundColor: highlightTextColor.value,
                          foregroundColor: menuColor.value,
                        ),
                        icon: const Icon(Icons.save_alt_rounded, size: 18),
                        label: Text(_l10n.exportToFile),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showImportQuirkSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheetContext) {
        return MySheet(
          height: MediaQuery.heightOf(sheetContext) * 0.85,
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  _l10n.importQuirkConfig,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _l10n.importQuirkConfigDesc,
                  style: TextStyle(
                    color: textColor.value.withAlpha(150),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: textColor.value.withAlpha(12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: controller,
                      maxLines: null,
                      expands: true,
                      cursorColor: highlightTextColor.value,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                        hintText: '{"version": 1, "devices": [...]}',
                        hintStyle: TextStyle(
                          color: textColor.value.withAlpha(100),
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _importQuirks(sheetContext, controller.text),
                    style: FilledButton.styleFrom(
                      backgroundColor: highlightTextColor.value,
                      foregroundColor: menuColor.value,
                    ),
                    icon: const Icon(Icons.file_download_done_rounded, size: 18),
                    label: Text(_l10n.importAction),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) => controller.dispose());
  }

  Future<void> _importQuirks(BuildContext sheetContext, String json) async {
    final error = await usbAudioService.importDacQuirks(json.trim());
    if (error == null && sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? _l10n.importQuirkSuccess
              : '${_l10n.importQuirkFailed}: $error',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyReport(String report) async {
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(_l10n.copiedForFeedback),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportReport(String report) async {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final timestamp =
        '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final fileName = 'usb_diag_$timestamp.txt';

    String directory;
    if (Platform.isAndroid) {
      final picked = await FilePicker.getDirectoryPath();
      if (picked == null) return;
      directory = picked;
    } else {
      directory = '${appDocsDir.path}/logs';
      Directory(directory).createSync(recursive: true);
    }

    final file = File(p.join(directory, fileName));
    file.writeAsStringSync(report);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(_l10n.exportedTo(file.path)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _exclusiveProbeSummary() {
    final result = _exclusiveProbeResult;
    if (result == null) return _l10n.probeDescription;
    if (!result.permissionGranted) return _l10n.probeWaitingAuth;
    if (result.interfaceClaimed) {
      return _l10n.probeClaimable(result.audioInterfaceCount);
    }
    return result.message ?? _l10n.probeCannotClaim;
  }

  String _sourceFormatLabel(MyAudioMetadata? song) {
    final format = song?.format;
    if (format == null || format.isEmpty) return _l10n.unknown;
    return format.toUpperCase();
  }

  String _channelCountLabel(UsbAudioStatus status) {
    final device = _activeUsbDevice(status);
    final channels = device?.channelCounts.isNotEmpty == true
        ? device!.channelCounts.first
        : null;
    if (channels == null || channels <= 0) return _l10n.unknown;
    return '$channels ch';
  }

  String _compactDepthLabel(UsbAudioStatus status) {
    return _bitDepthLabel(status, _l10n).replaceAll(' bits', '-bit');
  }

  String _usbIdLabel(UsbAudioStatus status) {
    final vendorId = status.vendorId;
    final productId = status.productId;
    if (vendorId == null || productId == null) return _l10n.unknown;
    return '${vendorId.toRadixString(16).padLeft(4, '0')}:'
        '${productId.toRadixString(16).padLeft(4, '0')}';
  }

  String _dsdModeLabel(UsbDsdMode mode) {
    return switch (mode) {
      UsbDsdMode.pcm => 'PCM',
      UsbDsdMode.dop => 'DoP',
      UsbDsdMode.native => 'Native',
    };
  }

  String _dsdModeHint(UsbDsdMode mode) {
    return switch (mode) {
      UsbDsdMode.pcm => _l10n.dsdToPcm,
      UsbDsdMode.dop => _l10n.dsdToPcmDesc,
      UsbDsdMode.native => _l10n.dsdNativeDesc,
    };
  }

  String _volumeControlLabel(UsbVolumeControlMode mode) {
    return switch (mode) {
      UsbVolumeControlMode.auto => _l10n.usbAuto,
      UsbVolumeControlMode.dac => _l10n.volumeControlDac,
      UsbVolumeControlMode.digital => _l10n.volumeControlDigital,
      UsbVolumeControlMode.raw => _l10n.volumeControlRaw,
    };
  }

  String _replayGainLabel(ReplayGainMode mode) {
    return switch (mode) {
      ReplayGainMode.track => _l10n.replayGainTrack,
      ReplayGainMode.album => _l10n.replayGainAlbum,
      ReplayGainMode.off => _l10n.replayGainOff,
    };
  }

  String _replayGainHint(ReplayGainMode mode) {
    return switch (mode) {
      ReplayGainMode.track => _l10n.replayGainTrackDesc,
      ReplayGainMode.album => _l10n.replayGainAlbumDesc,
      ReplayGainMode.off => _l10n.replayGainOffDesc,
    };
  }

  String _bitDepthModeLabel(UsbBitDepthMode mode) {
    return switch (mode) {
      UsbBitDepthMode.auto => _l10n.usbAuto,
      UsbBitDepthMode.pcm16 => '16 bits',
      UsbBitDepthMode.pcm24 => '24 bits',
      UsbBitDepthMode.pcm32 => '32 bits',
    };
  }
}

UsbAudioDevice? _activeUsbDevice(UsbAudioStatus status) {
  for (final device in status.devices) {
    if (device.id == status.bestAvailableDeviceId) {
      return device;
    }
  }
  return null;
}

String _bitDepthLabel(UsbAudioStatus status, AppLocalizations l10n) {
  final exclusive = usbExclusivePlaybackStateNotifier.value;
  if (exclusive.active && exclusive.bitDepth != null) {
    return '${exclusive.bitDepth} bits';
  }

  final encoding = status.preferredEncoding ?? status.outputEncoding;
  if (encoding == 'pcm_float') return '32 bits';
  if (encoding == 'pcm_32bit') return '32 bits';
  if (encoding == 'pcm_24bit_packed') return '24 bits';
  if (encoding == 'pcm_16bit') return '16 bits';
  return l10n.unknown;
}
