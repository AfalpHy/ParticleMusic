import 'dart:async';
import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/full_width_track_shape.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

final List<int> freqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
List<double> gains = List.filled(freqs.length, 0);

class EqualizerWidget extends StatefulWidget {
  const EqualizerWidget({super.key});

  @override
  State<EqualizerWidget> createState() => _EqualizerWidgetState();
}

class _EqualizerWidgetState extends State<EqualizerWidget> {
  Timer? _debounce;

  void _updateEQDebounced() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 200),
      audioHandler.applyEqualizer,
    );
  }

  void _reset() {
    gains.setAll(0, List.filled(freqs.length, 0));
    audioHandler.applyEqualizer();
    setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Widget _buildSlider(int i) {
    return Column(
      children: [
        Text(
          '${gains[i].toStringAsFixed(0)} dB',
          style: TextStyle(fontSize: 12),
        ),
        SizedBox(height: 15),
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbColor: iconColor.value,
                trackHeight: 4,
                trackShape: const FullWidthTrackShape(),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: iconColor.value,
                inactiveTrackColor: Colors.black12,
              ),
              child: Slider(
                min: -12,
                max: 12,
                value: gains[i],
                onChanged: (value) {
                  setState(() {
                    gains[i] = value;
                  });
                  _updateEQDebounced();
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(_formatFreq(freqs[i]), style: TextStyle(fontSize: 12)),
      ],
    );
  }

  String _formatFreq(int f) {
    if (f >= 1000) return '${f ~/ 1000}k';
    return '$f';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),

          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: freqs.length,
              itemBuilder: (_, i) =>
                  SizedBox(width: 50, child: _buildSlider(i)),
            ),
          ),
          SizedBox(height: 10),
          ValueListenableBuilder(
            valueListenable: buttonColor.valueNotifier,
            builder: (context, value, child) {
              return ElevatedButton(
                onPressed: () => _reset(),
                style: ElevatedButton.styleFrom(backgroundColor: value),
                child: Text(AppLocalizations.of(context).reset),
              );
            },
          ),
        ],
      ),
    );
  }
}
