// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get title => '歌名';

  @override
  String get artist => '艺术家';

  @override
  String get album => '专辑';

  @override
  String get artists => '艺术家';

  @override
  String get albums => '专辑';

  @override
  String get folders => '文件夹';

  @override
  String get songs => '所有歌曲';

  @override
  String get playlists => '歌单';

  @override
  String get language => '语言';

  @override
  String get playQueue => '播放列表';

  @override
  String get followSystem => '跟随系统';

  @override
  String get settings => '设置';

  @override
  String get reload => '重新加载';

  @override
  String get selectMusicFolder => '选择音乐文件夹';

  @override
  String get openSourceLicense => '开源许可证';

  @override
  String get sleepTimer => '定时关闭';

  @override
  String get pauseAfterCurrentTrack => '播完整首歌再关闭';

  @override
  String get vibration => '振动';

  @override
  String get library => '音乐库';

  @override
  String get select => '批量选择';

  @override
  String get sortSongs => '歌曲排序';

  @override
  String get delete => '删除';

  @override
  String get remove => '移除';

  @override
  String get createPlaylist => '创建歌单';

  @override
  String get order => '顺序';

  @override
  String get reorder => '调整顺序';

  @override
  String songsCount(int count) {
    return '$count 首';
  }

  @override
  String artistsCount(int count) {
    return '$count 人';
  }

  @override
  String albumsCount(int count) {
    return '$count 张';
  }

  @override
  String playlistsCount(int count) {
    return '$count 个';
  }

  @override
  String get searchSongs => '搜索歌曲';

  @override
  String get searchArtists => '搜索艺术家';

  @override
  String get searchAlbums => '搜索专辑';

  @override
  String get searchPlaylists => '搜索歌单';

  @override
  String get ascending => '升序';

  @override
  String get descending => '降序';

  @override
  String get pictureSize => '图片大小';

  @override
  String get large => '大';

  @override
  String get small => '小';

  @override
  String get view => '视图';

  @override
  String get list => '列表';

  @override
  String get grid => '网格';

  @override
  String get favorited => '喜欢';

  @override
  String get favorite => '最喜欢的音乐';

  @override
  String get duration => '时长';

  @override
  String get loop => '列表循环';

  @override
  String get shuffle => '随机播放';

  @override
  String get repeat => '单曲循环';

  @override
  String get playAll => '播放全部';

  @override
  String get playNow => '现在播放';

  @override
  String get playNext => '下一首播放';

  @override
  String get editMetadata => '编辑元数据';

  @override
  String get add2Playlists => '添加到歌单';
}
