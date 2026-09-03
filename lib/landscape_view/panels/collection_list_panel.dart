part of "../../base/widgets/collection_list.dart";

extension _CollectionListPanel on CollectionListState {
  Widget panelView(BuildContext context) {
    return Column(
      children: [
        TitleBar(
          hintText: searchHint,
          textController: textController,
          scrollToTop: () {
            scrollController.animateTo(
              0,
              duration: Duration(milliseconds: 250),
              curve: Curves.linear,
            );
          },
        ),
        Expanded(child: contentWidget(context)),
      ],
    );
  }

  Widget contentWidget(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: ListTile(
              leading: ValueListenableBuilder(
                valueListenable: iconColor.valueNotifier,
                builder: (context, value, child) {
                  return ImageIcon(image, size: 50, color: value);
                },
              ),
              title: Text(
                title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              subtitle: ValueListenableBuilder(
                valueListenable: changeNotifier,
                builder: (context, _, child) {
                  return Text(
                    countFunction(currentPictureList.length),
                    style: TextStyle(fontSize: 12),
                  );
                },
              ),
              trailing: SizedBox(
                width: isAscendingNotifier == null ? 100 : 320,
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Spacer(),
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            isAscendingNotifier,
                            randomizeNotifier,
                          ]),
                          builder: (context, child) {
                            if (isAscendingNotifier == null ||
                                (randomizeNotifier?.value ?? false)) {
                              return SizedBox.shrink();
                            }
                            return MySwitch(
                              trueText: l10n.ascending,
                              falseText: l10n.descending,
                              valueNotifier: isAscendingNotifier!,
                              onToggleCallBack: () {
                                setting.save();
                              },
                            );
                          },
                        ),

                        SizedBox(width: 5),
                        if (randomizeNotifier != null) ...[
                          MySwitch(
                            trueText: l10n.randomize,
                            falseText: l10n.normal,
                            valueNotifier: randomizeNotifier!,
                            onToggleCallBack: () {
                              updateCurrentList();
                            },
                          ),

                          SizedBox(width: 5),
                        ],

                        MySwitch(
                          trueText: l10n.large,
                          falseText: l10n.small,
                          valueNotifier: useLargePictureNotifier,
                          onToggleCallBack: () {
                            setting.save();
                          },
                        ),
                        SizedBox(width: 5),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: MyDivider(
            thickness: 0.5,
            height: 0.5,
            indent: 30,
            endIndent: 30,
            color: dividerColor,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 15)),

        panelGridView(),
      ],
    );
  }

  Widget panelGridView() {
    return ListenableBuilder(
      listenable: Listenable.merge([changeNotifier]),
      builder: (context, child) {
        if (preparing) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: iconColor.value),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 40),

          sliver: ValueListenableBuilder(
            valueListenable: useLargePictureNotifier,
            builder: (context, useLargePicture, child) {
              return SliverGrid.builder(
                gridDelegate: MyGirdDelegate(
                  maxCrossAxisExtent: useLargePicture ? 240 : 120,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 5,
                  textExtent: 30,
                ),
                itemCount: currentPictureList.length,
                itemBuilder: (context, index) {
                  final picture = currentPictureList[index];
                  final text = currentTextList[index];
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        children: [
                          InkWell(
                            mouseCursor: SystemMouseCursors.click,
                            focusColor: Colors.transparent,
                            splashColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,

                            child: Hero(
                              tag: (picture?.id ?? '') + label + text,
                              child: CoverArtWidget(
                                size: constraints.maxWidth,
                                borderRadius: constraints.maxWidth / 10,
                                picture: picture,
                              ),
                            ),
                            onTap: () {
                              currentOnTapList[index].call();
                            },
                          ),
                          SizedBox(height: 5),

                          SizedBox(
                            width: constraints.maxWidth - 10,
                            child: Center(
                              child: Text(
                                text,
                                textAlign: .center,
                                style: TextStyle(
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
