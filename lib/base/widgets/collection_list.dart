import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/data/loader.dart';
import 'package:sylvakru/base/services/interaction.dart';
import 'package:sylvakru/base/services/picture_service.dart';
import 'package:sylvakru/base/utils/my_gird_delegate.dart';
import 'package:sylvakru/base/widgets/cover_art_widget.dart';
import 'package:sylvakru/base/widgets/my_navigator.dart';
import 'package:sylvakru/base/widgets/my_sheet.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/base/data/setting.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/asset_images.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/base/widgets/my_switch.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';
import 'package:sylvakru/portrait_view/my_search_field.dart';

part '../../landscape_view/panels/collection_list_panel.dart';
part '../../portrait_view/pages/collection_list_page.dart';

abstract class CollectionList extends StatefulWidget {
  const CollectionList({super.key});
}

abstract class CollectionListState extends State<CollectionList> {
  final GlobalKey<NavigatorState> globalKey = GlobalKey();
  final visibleNotifier = ValueNotifier(true);

  List<MyPicture?> currentPictureList = [];
  List<String> currentTextList = [];
  List<int>? currentSubCountList;
  List<Function> currentOnTapList = [];

  final textController = TextEditingController();

  final ScrollController scrollController = ScrollController();

  ValueNotifier<bool>? randomizeNotifier;
  ValueNotifier<bool>? isAscendingNotifier;
  ValueNotifier<bool> useLargePictureNotifier = ValueNotifier(false);

  final isSearchNotifier = ValueNotifier(false);

  final changeNotifier = ValueNotifier(0);

  ValueNotifier<bool>? isListViewNotifier;

  String title = '';
  String searchHint = '';

  // for hero tag
  String label = '';

  late final AssetImage image;

  late final String Function(int) countFunction;

  void updateCurrentList();

  Future<void> fetchCollectionList() async {}

  bool _isLoadingMoreData = false;
  bool reachEnd = false;
  void _onScroll() async {
    if (_isLoadingMoreData | reachEnd) {
      return;
    }
    _isLoadingMoreData = true;

    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent) {
      await fetchCollectionList();
    }
    _isLoadingMoreData = false;
  }

  @override
  void initState() {
    super.initState();

    textController.addListener(updateCurrentList);
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    textController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return myNavigator(
      key: globalKey,
      visibleNotifier: visibleNotifier,
      pageViewBuilder: () => pageView(context),
      panelViewBuilder: () => panelView(context),
    );
  }
}
