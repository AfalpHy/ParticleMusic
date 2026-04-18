import 'dart:async';
import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/full_width_track_shape.dart';

final List<int> freqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
List<double> gains = List.filled(freqs.length, 0);

final Map<String, List<double>> presets = {
  "Flat": List.filled(10, 0),
  "Rock": [5, 3, -2, -3, 2, 4, 5, 6, 6, 6],
  "Pop": [-1, 2, 4, 5, 3, 0, -1, -1, 2, 3],
  "Bass Boost": [6, 5, 4, 2, 0, -2, -3, -4, -5, -6],
};

String currentPreset = "Flat";

class EqualizerWidget extends StatefulWidget {
  const EqualizerWidget({super.key});

  @override
  State<EqualizerWidget> createState() => _EqualizerWidgetState();
}

class _EqualizerWidgetState extends State<EqualizerWidget> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
  }

  void _applyEQ() {
    final af = [
      'aformat=sample_fmts=fltp',

      ...List.generate(freqs.length, (i) {
        return 'equalizer=f=${freqs[i]}:t=o:w=1:g=${gains[i]}';
      }),
    ].join(',');

    audioHandler.setAudioParams(af);
  }

  void _updateEQDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), _applyEQ);
  }

  void _setPreset(String name) {
    setState(() {
      currentPreset = name;
      gains = List.from(presets[name]!);
    });
    _applyEQ();
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
          style: TextStyle(
            fontSize: 12,
            color: colorManager.getSpecificTextColor(),
          ),
        ),
        SizedBox(height: 15),
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbColor: colorManager.getSpecificIconColor(),
                trackHeight: 4,
                trackShape: const FullWidthTrackShape(),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: colorManager.getSpecificIconColor(),
                inactiveTrackColor: Colors.black12,
              ),
              child: Slider(
                min: -12,
                max: 12,
                value: gains[i],
                onChanged: (value) {
                  setState(() {
                    gains[i] = value;
                    currentPreset = "Custom";
                  });
                  _updateEQDebounced();
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          _formatFreq(freqs[i]),
          style: TextStyle(
            fontSize: 12,
            color: colorManager.getSpecificTextColor(),
          ),
        ),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: presets.keys.map((name) {
                final selected = name == currentPreset;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text(
                      name,
                      style: .new(color: colorManager.getSpecificTextColor()),
                    ),
                    selectedColor: colorManager.getSpecificButtonColor(),
                    backgroundColor: colorManager.getSpecificButtonColor(),
                    selected: selected,
                    onSelected: (_) => _setPreset(name),
                  ),
                );
              }).toList(),
            ),
          ),

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
          ElevatedButton(
            onPressed: () => _setPreset("Flat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorManager.getSpecificButtonColor(),
              foregroundColor: colorManager.getSpecificTextColor(),
            ),
            child: Text("Reset"),
          ),
        ],
      ),
    );
  }
}
