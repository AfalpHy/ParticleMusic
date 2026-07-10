import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_font_scan/just_font_scan.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/library.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';

abstract class FontPickerBase extends StatefulWidget {
  const FontPickerBase({super.key});
}

abstract class FontPickerBaseState extends State<FontPickerBase> {
  final textController = TextEditingController();
  final ValueNotifier<List<String>> fontsNotifier = ValueNotifier([]);
  List<String> allFonts = [];

  final previewText = "Music 音乐 123";

  @override
  void initState() {
    super.initState();
    reloadAllFonts();
    textController.addListener(update);
  }

  void reloadAllFonts() {
    allFonts.clear();
    allFonts.addAll(importedFonts);
    if (Platform.isWindows || Platform.isMacOS) {
      allFonts.addAll(JustFontScan.scan().map((e) => e.name).toList());
    }
    update();
  }

  void update() {
    fontsNotifier.value = allFonts.where((font) {
      return font.toLowerCase().contains(textController.text.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  void restoreDefaultAction() async {
    final l10n = AppLocalizations.of(context);

    if (await showConfirmDialog(context, l10n.restoreDefault)) {
      await Future.delayed(Duration(milliseconds: 250));
      fontFamilyNotifier.value = null;
      setting.save();
      setState(() {});
    }
  }

  void addFontAction(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    final fileResult = await FilePicker.pickFiles(
      type: .custom,
      allowedExtensions: ['ttf', 'otf', 'ttc'],
    );
    if (fileResult != null) {
      if (context.mounted) {
        final result = await getInputTextDialog(context, l10n.setFontName);
        if (result == '') {
          return;
        }
        if (Platform.isMacOS || Platform.isWindows) {
          for (final font in JustFontScan.scan().map((e) => e.name).toList()) {
            if (font == result) {
              if (context.mounted) {
                showCenterMessage(context, 'Conflict name with system font');
              }
              return;
            }
          }
        }
        final loader = FontLoader(result);

        for (final file in fileResult.files) {
          final bytes = await File(file.path!).readAsBytes();
          loader.addFont(Future.value(ByteData.view(bytes.buffer)));
        }

        await loader.load();

        await library.addFonts(
          result,
          fileResult.files.map((e) => e.path!).toList(),
        );

        if (importedFonts.contains(result)) {
          setState(() {});
        } else {
          importedFonts.add(result);
          allFonts.clear();
          reloadAllFonts();
        }
      }
    }
  }

  void deleteFontAction(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    await showAnimationDialog(
      context: context,
      child: SizedBox(
        width: 300,
        height: 350,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: StatefulBuilder(
            builder: (context, thisSetState) {
              return ListView.builder(
                itemCount: importedFonts.length,
                itemBuilder: (context, index) {
                  final font = importedFonts[index];
                  return ListTile(
                    title: Text(font),
                    onTap: () async {
                      if (await showConfirmDialog(context, l10n.deleteFont)) {
                        await library.deleteFonts(font);

                        if (importedFonts.isEmpty && context.mounted) {
                          Navigator.pop(context);
                          await Future.delayed(Duration(milliseconds: 250));
                        } else {
                          thisSetState(() {});
                        }

                        if (font == fontFamilyNotifier.value) {
                          fontFamilyNotifier.value = null;
                          setting.save();
                        }

                        reloadAllFonts();
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
