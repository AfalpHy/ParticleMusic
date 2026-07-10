import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

/// 独占模式下按安卓物理音量键时弹出的右侧竖向音量条：整条可点/拖调节，
/// 百分比直接显示在条内，静止约 2 秒后自动隐藏。系统音量条已被 MainActivity
/// 拦截，改由本条反馈与操作。叠在 MaterialApp 之上（需 Stack 父级），
/// 只在收到物理音量键事件时显示。DSD 独占不会触发（1-bit 码流无法软件调音量）。
class UsbExclusiveVolumeOverlay extends StatefulWidget {
  const UsbExclusiveVolumeOverlay({super.key});

  @override
  State<UsbExclusiveVolumeOverlay> createState() =>
      _UsbExclusiveVolumeOverlayState();
}

class _UsbExclusiveVolumeOverlayState extends State<UsbExclusiveVolumeOverlay> {
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    usbExclusiveVolumeKeyNotifier.addListener(_show);
  }

  @override
  void dispose() {
    usbExclusiveVolumeKeyNotifier.removeListener(_show);
    _hideTimer?.cancel();
    super.dispose();
  }

  // 显示并重置自动隐藏计时；拖动时也调用它保持常驻。
  void _show() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _visible = false);
    });
    if (!_visible) {
      setState(() => _visible = true);
    }
  }

  void _applyVolume(double next) {
    volumeNotifier.value = next;
    audioHandler.setVolume(next);
    _show();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // 固定尺寸避免被松约束撑爆：右侧短竖条，高度取屏高约三成并封顶。
    final height = (media.size.height * 0.28).clamp(220.0, 320.0);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_visible,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0.25, 0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(width: 44, height: height, child: _bar()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar() {
    return ValueListenableBuilder<ThemeType>(
      valueListenable: mainPageThemeNotifier,
      builder: (context, theme, _) {
        return ValueListenableBuilder<double>(
          valueListenable: volumeNotifier,
          builder: (context, volume, _) {
            final accent = iconColor.value; // 填充色，走作者单色范式
            final clamped = volume.clamp(0.0, 1.0);
            final percent = (clamped * 100).round();
            final dark = theme == ThemeType.dark;
            final pageColor = colorManager.getSpecificBgBaseColor();
            return _track(
              accent,
              clamped,
              percent,
              _trackColor(pageColor, dark),
              textColor.value.withAlpha(dark ? 55 : 34),
              panelColor.value.withAlpha(245),
              _fillColors(pageColor),
            );
          },
        );
      },
    );
  }

  // 整条即触控区：按点击/拖动纵向落点直接换算音量并下发，避免旋转 Slider 手势失灵。
  Widget _track(
    Color accent,
    double value,
    int percent,
    Color trackColor,
    Color borderColor,
    Color labelColor,
    List<Color> fillColors,
  ) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.none,
    );
    final label = '$percent%';
    return LayoutBuilder(
      builder: (context, constraints) {
        const trackTop = 8.0;
        const trackBottomPadding = 8.0;
        const trackWidth = 32.0;
        final trackBottom = constraints.maxHeight - trackBottomPadding;
        final trackHeight = trackBottom - trackTop;
        final labelBottom = (trackHeight * value - 15).clamp(
          6.0,
          trackHeight - 20,
        );
        void updateFromDy(double dy) {
          if (trackHeight <= 0) return;
          final localDy = dy.clamp(trackTop, trackBottom);
          _applyVolume(
            (1 - (localDy - trackTop) / trackHeight).clamp(0.0, 1.0),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => updateFromDy(details.localPosition.dy),
          onTapUp: (_) => audioHandler.savePlayState(),
          onVerticalDragStart: (details) =>
              updateFromDy(details.localPosition.dy),
          onVerticalDragUpdate: (details) =>
              updateFromDy(details.localPosition.dy),
          onVerticalDragEnd: (_) => audioHandler.savePlayState(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                top: trackTop,
                bottom: trackBottomPadding,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: trackWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(42),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: value,
                                widthFactor: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: fillColors,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                width: 7,
                                margin: const EdgeInsets.only(
                                  top: 10,
                                  bottom: 10,
                                  right: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(38),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                            CustomPaint(
                              painter: _VolumeDotsPainter(
                                color: labelColor.withAlpha(160),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: labelBottom,
                              child: Center(
                                child: Text(
                                  label,
                                  style: style.copyWith(
                                    color: labelColor,
                                    shadows: [
                                      Shadow(
                                        color: accent.withAlpha(90),
                                        blurRadius: 4,
                                      ),
                                      Shadow(
                                        color: Colors.black.withAlpha(70),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Color> _fillColors(Color pageColor) {
    final hsl = HSLColor.fromColor(pageColor.withAlpha(255));
    final hue = hsl.saturation < 0.08 ? 38.0 : hsl.hue;
    final saturation = (hsl.saturation + 0.35).clamp(0.55, 0.95).toDouble();
    return [
      HSLColor.fromAHSL(1, hue, saturation, 0.72).toColor(),
      HSLColor.fromAHSL(1, (hue + 14) % 360, saturation, 0.58).toColor(),
      HSLColor.fromAHSL(1, (hue + 28) % 360, saturation, 0.42).toColor(),
    ];
  }

  Color _trackColor(Color pageColor, bool dark) {
    final hsl = HSLColor.fromColor(pageColor.withAlpha(255));
    return hsl
        .withSaturation((hsl.saturation + 0.12).clamp(0.18, 0.65).toDouble())
        .withLightness(dark ? 0.22 : 0.36)
        .toColor()
        .withAlpha(dark ? 120 : 98);
  }
}

class _VolumeDotsPainter extends CustomPainter {
  const _VolumeDotsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final centerX = size.width / 2;
    for (var y = 12.0; y < size.height - 8; y += 11) {
      canvas.drawCircle(Offset(centerX, y), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_VolumeDotsPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
