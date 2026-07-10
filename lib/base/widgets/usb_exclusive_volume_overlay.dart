import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

/// 独占模式下按安卓物理音量键时弹出的右侧竖向毛玻璃音量条：整条可点/拖调节，
/// 数字显示在条内，中间细轨道显示当前音量，静止约 2 秒后自动隐藏。系统音量条
/// 已被 MainActivity 拦截，改由本条反馈与操作。叠在 MaterialApp 之上（需 Stack 父级），
/// 只在收到物理音量键事件时显示。DSD 独占不会触发（1-bit 码流无法软件调音量）。
class UsbExclusiveVolumeOverlay extends StatefulWidget {
  const UsbExclusiveVolumeOverlay({super.key});

  @override
  State<UsbExclusiveVolumeOverlay> createState() =>
      _UsbExclusiveVolumeOverlayState();
}

class _UsbExclusiveVolumeOverlayState extends State<UsbExclusiveVolumeOverlay>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  Timer? _hideTimer;
  late final AnimationController _lavaController;

  @override
  void initState() {
    super.initState();
    _lavaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    usbExclusiveVolumeKeyNotifier.addListener(_show);
  }

  @override
  void dispose() {
    usbExclusiveVolumeKeyNotifier.removeListener(_show);
    _hideTimer?.cancel();
    _lavaController.dispose();
    super.dispose();
  }

  // 显示并重置自动隐藏计时；拖动时也调用它保持常驻。
  void _show() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _lavaController.stop();
        setState(() => _visible = false);
      }
    });
    if (!_lavaController.isAnimating) {
      _lavaController.repeat();
    }
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
                  child: SizedBox(width: 58, height: height, child: _bar()),
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
            final clamped = volume.clamp(0.0, 1.0);
            final percent = (clamped * 100).round();
            final dark = theme == ThemeType.dark;
            final foreground = textColor.value;
            final pageColor = colorManager.getSpecificBgBaseColor();
            final trackColor = _trackColor(pageColor, dark);
            final borderColor = foreground.withAlpha(dark ? 55 : 30);
            final labelColor = panelColor.value.withAlpha(245);
            final lavaColors = _lavaColors(pageColor);
            return _track(
              clamped,
              percent,
              labelColor,
              trackColor,
              borderColor,
              lavaColors,
            );
          },
        );
      },
    );
  }

  // 整条即触控区：按点击/拖动纵向落点直接换算音量并下发，避免旋转 Slider 手势失灵。
  Widget _track(
    double value,
    int percent,
    Color labelColor,
    Color trackColor,
    Color borderColor,
    List<Color> lavaColors,
  ) {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.none,
    );
    final label = '$percent%';
    return LayoutBuilder(
      builder: (context, constraints) {
        const trackTop = 12.0;
        const trackBottomPadding = 12.0;
        const trackWidth = 34.0;
        final trackBottom = constraints.maxHeight - trackBottomPadding;
        final trackHeight = trackBottom - trackTop;
        final labelBottom = (trackHeight * value - 17).clamp(
          5.0,
          trackHeight - 22,
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
                            color: Colors.black.withAlpha(35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: panelColor.value.withAlpha(150),
                            blurRadius: 5,
                            offset: const Offset(-1, -1),
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
                                child: AnimatedBuilder(
                                  animation: _lavaController,
                                  builder: (context, _) {
                                    return CustomPaint(
                                      painter: _LavaPainter(
                                        progress: _lavaController.value,
                                        colors: lavaColors,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            CustomPaint(
                              painter: _VolumeDotsPainter(
                                color: panelColor.value.withAlpha(190),
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

  List<Color> _lavaColors(Color pageColor) {
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
        .withAlpha(dark ? 115 : 95);
  }
}

class _LavaPainter extends CustomPainter {
  const _LavaPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: colors,
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    for (var i = 0; i < 5; i++) {
      final phase = (progress + i * 0.19) % 1;
      final x = size.width * (0.22 + 0.56 * ((i * 37) % 10) / 10);
      final y = size.height * (1 - phase);
      final radius = 3.0 + i % 3;
      final glow = Paint()..color = colors.first.withAlpha(70 - i * 8);
      canvas.drawCircle(Offset(x, y), radius, glow);
    }
  }

  @override
  bool shouldRepaint(_LavaPainter oldDelegate) {
    return progress != oldDelegate.progress || colors != oldDelegate.colors;
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
      canvas.drawCircle(Offset(centerX, y), 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(_VolumeDotsPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
