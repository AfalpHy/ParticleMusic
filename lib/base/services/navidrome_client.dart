import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/open_sonic_client.dart';

NavidromeClient? navidromeClient;

class NavidromeClient extends OpenSubsonicClient {
  NavidromeClient({
    required super.baseUrl,
    required super.username,
    required super.password,
  });

  @override
  Stream<List<Map<String, dynamic>>> getSongs({int limit = 50}) async* {
    int offset = 0;
    int count = 0;

    while (true) {
      final res = await safeRequest(
        () => get(
          '/rest/search3.view',
          query: {'query': '', 'songCount': limit, 'songOffset': offset},
        ),
        (data) => data,
      );

      if (res == null) {
        break;
      }

      final songs = normalize(
        res['subsonic-response']['searchResult3']['song'],
      );

      if (songs.isEmpty) {
        break;
      }

      yield songs;

      count += songs.length;
      offset += limit;

      logger.output('[Navidrome] Fetched $count songs...');
    }
  }

  @override
  Future<bool> scrobble(String songId) async {
    return await safeRequest(
          () => get('/rest/scrobble.view', query: {'id': songId}),
          (_) => true,
        ) ??
        false;
  }
}
