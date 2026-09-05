part of '../../layer/font_picker_layer.dart';

extension _FontPickerPage on _FontPickerLayerState {
  Widget pageView(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          customAppBar(context),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: fontsNotifier,
              builder: (context, fonts, child) {
                return pageContent(fonts);
              },
            ),
          ),

          SizedBox(height: 50),
        ],
      ),
    );
  }

  PreferredSizeWidget customAppBar(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leading: customAppBarLeading(context, label: 'settings'),
      backgroundColor: Colors.transparent,
      systemOverlayStyle: mainPageThemeNotifier.value == .dark ? .light : .dark,
      scrolledUnderElevation: 0,
      actions: [
        MySearchField(
          hintText: AppLocalizations.of(context).searchFonts,
          textController: textController,
        ),

        moreButton(context),
      ],
    );
  }

  Widget moreButton(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.more_vert),
      onPressed: () {
        tryVibrate();

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useRootNavigator: true,
          builder: (context) {
            return moreSheet(context);
          },
        );
      },
    );
  }

  Widget moreSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MySheet(
      Column(
        children: [
          ListTile(title: Text(l10n.settings)),
          MyDivider(thickness: 0.5, height: 1, color: dividerColor),

          ListTile(
            title: Text(
              l10n.restoreDefault,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: restoreDefaultAction,
          ),

          ListTile(
            title: Text(
              l10n.addFont,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () => addFontAction(context),
          ),

          ListTile(
            title: Text(
              l10n.deleteFont,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
            onTap: () => deleteFontAction(context),
          ),
        ],
      ),
    );
  }

  Widget pageContent(List<String> fonts) {
    final l10n = AppLocalizations.of(context);

    return ListView.builder(
      itemCount: fonts.length + 1,
      padding: .zero,
      itemBuilder: (context, index) {
        String? font;
        late String title;
        if (index == 0) {
          title =
              "${l10n.currentFont}: ${fontFamilyNotifier.value ?? l10n.defaultText}";
          font = fontFamilyNotifier.value;
        } else {
          font = fonts[index - 1];
          title = font;
        }

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),

          title: oneFontPreview(title, font),
          onTap: index > 0
              ? () async {
                  if (await showConfirmDialog(context, l10n.setFont)) {
                    await Future.delayed(Duration(milliseconds: 250));
                    fontFamilyNotifier.value = font;
                    setting.save();
                    rebuild();
                  }
                }
              : null,
        );
      },
    );
  }

  Widget oneFontPreview(String title, String? font) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontFamily: font, fontSize: 16)),

        const SizedBox(height: 6),

        Text(
          previewText,
          style: TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.w300,
            fontSize: 24,
          ),
        ),

        Text(
          previewText,
          style: TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.normal,
            fontSize: 24,
          ),
        ),

        Text(
          previewText,
          style: TextStyle(
            fontFamily: font,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ],
    );
  }
}
