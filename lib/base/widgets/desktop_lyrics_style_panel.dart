import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_font_scan/just_font_scan.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/desktop_lyrics.dart';

/// Settings panel for the floating desktop lyrics window's appearance.
/// Every change here is pushed live to the (separate-isolate) lyrics window
/// via [pushDesktopLyricsStyle] and persisted through [setting.save], so the
/// lyrics window picks it up immediately if it's currently visible.
class DesktopLyricsStylePanel extends StatefulWidget {
  const DesktopLyricsStylePanel({super.key});

  @override
  State<DesktopLyricsStylePanel> createState() =>
      _DesktopLyricsStylePanelState();
}

class _DesktopLyricsStylePanelState extends State<DesktopLyricsStylePanel> {
  void _applyAndPersist() {
    setting.save();
    pushDesktopLyricsStyle();
    setState(() {});
  }

  Future<void> _pickColor(ValueNotifier<Color> notifier) async {
    final picked = await showColorPickerDialog(
      context,
      notifier.value,
      enableOpacity: true,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.primary: false,
        ColorPickerType.accent: false,
        ColorPickerType.wheel: true,
      },
    );
    notifier.value = picked;
    _applyAndPersist();
  }

  Widget _colorTile(String label, ValueNotifier<Color> notifier) {
    return ListTile(
      title: Text(label),
      onTap: () => _pickColor(notifier),
      trailing: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: notifier.value,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey),
        ),
      ),
    );
  }

  Future<void> _pickFont() async {
    final l10n = AppLocalizations.of(context);
    final fonts = <String>[...importedFonts];
    if (Platform.isWindows || Platform.isMacOS) {
      fonts.addAll(JustFontScan.scan().map((e) => e.name));
    }

    await showAnimationDialog(
      context: context,
      child: SizedBox(
        width: 300,
        height: 400,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: ListView(
            children: [
              ListTile(
                title: Text(l10n.followSystem),
                trailing: desktopLyricsFontFamilyNotifier.value == null
                    ? Icon(Icons.check)
                    : null,
                onTap: () {
                  desktopLyricsFontFamilyNotifier.value = null;
                  Navigator.pop(context);
                  _applyAndPersist();
                },
              ),
              for (final font in fonts)
                ListTile(
                  title: Text(font),
                  trailing: desktopLyricsFontFamilyNotifier.value == font
                      ? Icon(Icons.check)
                      : null,
                  onTap: () {
                    desktopLyricsFontFamilyNotifier.value = font;
                    Navigator.pop(context);
                    _applyAndPersist();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      children: [
        ListTile(
          title: Text(l10n.lineMode),
          trailing: SegmentedButton<DesktopLyricsLineMode>(
            segments: [
              ButtonSegment(value: .single, label: Text(l10n.singleLine)),
              ButtonSegment(value: .double, label: Text(l10n.doubleLine)),
            ],
            selected: {desktopLyricsLineModeNotifier.value},
            onSelectionChanged: (selection) {
              desktopLyricsLineModeNotifier.value = selection.first;
              _applyAndPersist();
            },
          ),
        ),
        ListTile(
          title: Text(l10n.fonts),
          trailing: Text(
            desktopLyricsFontFamilyNotifier.value ?? l10n.followSystem,
          ),
          onTap: _pickFont,
        ),
        ListTile(
          title: Text(
            '${l10n.fontSize}: ${desktopLyricsFontSizeNotifier.value.round()}',
          ),
          subtitle: Slider(
            min: 16,
            max: 60,
            divisions: 44,
            value: desktopLyricsFontSizeNotifier.value,
            onChanged: (v) {
              desktopLyricsFontSizeNotifier.value = v;
              setState(() {});
            },
            onChangeEnd: (v) => _applyAndPersist(),
          ),
        ),
        _colorTile(l10n.lyricColor, desktopLyricsColorNotifier),
        _colorTile(l10n.sungLyricColor, desktopLyricsSungColorNotifier),
        _colorTile(l10n.outlineColor, desktopLyricsOutlineColorNotifier),
        _colorTile(l10n.nextLineColor, desktopLyricsNextLineColorNotifier),
      ],
    );
  }
}
