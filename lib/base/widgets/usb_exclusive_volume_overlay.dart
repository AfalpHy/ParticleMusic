import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/usb_audio_service.dart';

/// 独占模式下按安卓物理音量键时弹出的右侧竖向毛玻璃音量条：整条可点/拖调节，
/// 顶部显示百分比，中间细轨道显示当前音量，静止约 2 秒后自动隐藏。系统音量条
/// 已被 MainActivity 拦截，改由本条反馈与操作。叠在 MaterialApp 之上（需 Stack 父级），
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
    // 固定尺寸避免被松约束撑爆：右侧窄竖条，高度取屏高四成并封顶。
    final height = (media.size.height * 0.4).clamp(280.0, 420.0);
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
            final accent = iconColor.value; // 填充色，走作者单色范式
            final clamped = volume.clamp(0.0, 1.0);
            final percent = (clamped * 100).round();
            final dark = theme == ThemeType.dark;
            final foreground = textColor.value;
            final trackColor = foreground.withAlpha(dark ? 42 : 24);
            final labelColor = foreground.withAlpha(dark ? 36 : 18);
            return ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: panelColor.value.withAlpha(dark ? 205 : 235),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: textColor.value.withAlpha(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(dark ? 70 : 26),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: _track(
                    accent,
                    clamped,
                    percent,
                    foreground,
                    trackColor,
                    labelColor,
                  ),
                ),
              ),
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
    Color foreground,
    Color trackColor,
    Color labelColor,
  ) {
    const style = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.none,
    );
    final label = '$percent%';
    return LayoutBuilder(
      builder: (context, constraints) {
        const trackTop = 62.0;
        const trackBottomPadding = 18.0;
        final trackBottom = constraints.maxHeight - trackBottomPadding;
        final trackHeight = trackBottom - trackTop;
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
                top: 15,
                left: 0,
                right: 0,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: labelColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 5,
                      ),
                      child: Text(
                        label,
                        style: style.copyWith(color: foreground),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: trackTop,
                bottom: trackBottomPadding,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 14,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: value,
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
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
}
