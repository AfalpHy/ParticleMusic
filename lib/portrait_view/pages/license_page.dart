part of '../../layer/license_layer.dart';

extension _LicensePage on _LicenseLayerState {
  Widget pageView(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          customAppBar(context),
          Expanded(child: pageContent()),
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
          hintText: AppLocalizations.of(context).searchLicenses,
          textController: textController,
        ),
      ],
    );
  }

  Widget pageContent() {
    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView.builder(
              itemCount: packages.length,
              itemBuilder: (context, index) {
                final pkg = packages[index];

                return ListenableBuilder(
                  listenable: Listenable.merge([
                    iconColor.valueNotifier,
                    textColor.valueNotifier,
                  ]),
                  builder: (context, _) {
                    return ExpansionTile(
                      iconColor: iconColor.value,
                      collapsedIconColor: iconColor.value,
                      title: Text(pkg, style: .new(color: textColor.value)),
                      children: [
                        SizedBox(height: 500, child: buildLicenseDetail(pkg)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
        SizedBox(height: 90),
      ],
    );
  }
}
