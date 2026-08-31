import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/utils/my_gird_delegate.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/scale_widget.dart';

abstract class BigCollectionListPanel extends StatefulWidget {
  const BigCollectionListPanel({super.key});
}

abstract class BigCollectionListPanelState
    extends State<BigCollectionListPanel> {
  List<MyPicture?> pictureList = [];
  List<String> textList = [];
  List<Function> onTapList = [];

  final textController = TextEditingController();

  final randomizeNotifier = ValueNotifier(false);
  final isAscendingNotifier = ValueNotifier(false);

  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

  final scrollController = ScrollController();

  bool firstLoading = true;

  void updateCurrentList();

  @override
  void dispose() {
    textController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (firstLoading) {
      return Center(child: CircularProgressIndicator(color: iconColor.value));
    }
    return GridView.builder(
      controller: scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: isTooNarrow(context) ? 20 : 40,
        vertical: 75 + getTopOffset(context),
      ),
      gridDelegate: MyGirdDelegate(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 20,
        mainAxisSpacing: 10,
        textExtent: 30,
      ),
      itemCount: pictureList.length,
      itemBuilder: (context, index) {
        final picture = pictureList[index];

        return Builder(
          builder: (context) {
            return ScaleWidget(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      Hero(
                        tag: 'big${picture?.id ?? ''}${textList[index]}',
                        child: CoverArtWidget(
                          size: constraints.maxWidth,
                          borderRadius: constraints.maxWidth * 0.1,
                          picture: picture,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, 5),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Align(
                            alignment: .centerLeft,
                            child: Text(
                              textList[index],
                              style: TextStyle(overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              onTap: () async {
                onTapList[index].call();
              },

              onFocus: () {
                final box = context.findRenderObject() as RenderBox;
                final viewport = RenderAbstractViewport.of(box);

                final target = viewport.getOffsetToReveal(box, 0.5).offset;

                scrollController.animateTo(
                  target.clamp(
                    scrollController.position.minScrollExtent,
                    scrollController.position.maxScrollExtent,
                  ),
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                );
              },
            );
          },
        );
      },
    );
  }
}
