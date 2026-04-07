import 'package:flutter/material.dart';

class AdaptiveContrastColorTextTheme {
  final Color regular;
  final Color accent;

  AdaptiveContrastColorTextTheme({required this.regular, required this.accent});
}

class AdaptiveContrastColorGenerator {
  /// Regular: High-contrast complementary tint for best readability.
  /// Accent: Subtle neighboring hue for a gentle highlight.
  static AdaptiveContrastColorTextTheme generate(Color backgroundColor) {
    final hsl = HSLColor.fromColor(backgroundColor);
    final double luminance = backgroundColor.computeLuminance();
    final bool isDark = luminance < 0.45;

    // --- 1. Regular Text (Optimized for Readability) ---
    // We use the 180° hue shift but keep saturation very low.
    // This "cuts" through the background color so it doesn't look blurry.
    Color regularColor = HSLColor.fromAHSL(
      1.0,
      (hsl.hue + 180) % 360,
      0.10, // Very low saturation to keep it clean
      isDark ? 0.90 : 0.15, // High contrast for clarity
    ).toColor();

    // --- 2. Subtle Accent Color ---
    // Logic: Instead of rotating 180°, we only rotate 15-30°.
    // We increase saturation slightly to make it "pop" without clashing.
    Color accentColor = HSLColor.fromAHSL(
      1.0,
      (hsl.hue + 20) % 360, // Slight shift to a neighboring hue
      (hsl.saturation + 0.3).clamp(0.4, 0.6), // Moderate saturation boost
      isDark
          ? 0.95
          : 0.15, // Make it slightly closer to white/black than the regular text
    ).toColor();

    return AdaptiveContrastColorTextTheme(
      regular: regularColor,
      accent: accentColor,
    );
  }
}
