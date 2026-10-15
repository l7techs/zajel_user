// CUSTOM: tests for features/remote_splash (splash video from the admin panel).
// Rules: flutter test test/remote_splash_test.dart
// Real download against the local backend (bash tools/local/start-backend.sh, with a splash uploaded):
//   flutter test test/remote_splash_test.dart --dart-define=SPLASH_TEST_API=http://127.0.0.1:8000/api/v1/app-splash
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixam_mart/api/api_client.dart';
import 'package:sixam_mart/features/remote_splash/domain/models/remote_splash_model.dart';
import 'package:sixam_mart/features/remote_splash/domain/repositories/remote_splash_repository.dart';
import 'package:sixam_mart/features/remote_splash/domain/repositories/remote_splash_repository_interface.dart';
import 'package:sixam_mart/features/remote_splash/domain/services/remote_splash_service.dart';

/// In-memory server + phone storage; files go to a temp folder.
class FakeRepo implements RemoteSplashRepositoryInterface {
  FakeRepo(this.root);
  final Directory root;
  RemoteSplashInfo? info;
  final Map<String, List<int>> files = {}; // url → bytes on the "server"
  final Set<String> failingUrls = {};
  String? stored;

  @override
  Future<RemoteSplashInfo?> getSplashInfo() async => info;
  @override
  String? getStored() => stored;
  @override
  Future<void> saveStored(String value) async => stored = value;
  @override
  Future<Directory> splashDirectory(String version) async => Directory('${root.path}/$version')..createSync(recursive: true);
  @override
  Future<bool> download(String url, File target, {int? expectedSize}) async {
    if (failingUrls.contains(url) || !files.containsKey(url)) return false;
    await target.writeAsBytes(files[url]!);
    return true;
  }
  @override
  Future<String> sha256Of(File file) async => sha256.convert(await file.readAsBytes()).toString();
  @override
  Future<void> deleteDirectoryOf(String path) async {
    final Directory dir = File(path).parent;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

RemoteSplashModel splash(FakeRepo repo, int id, String content, {String? start, String? end, bool corrupt = false}) {
  final List<int> video = utf8.encode('video-$content');
  final List<int> image = utf8.encode('image-$content');
  final String videoUrl = 'https://x/$id-$content.mp4';
  final String imageUrl = 'https://x/$id-$content.webp';
  repo.files[videoUrl] = corrupt ? utf8.encode('video-BROKEN') : video;
  repo.files[imageUrl] = image;
  final String sha = sha256.convert(video).toString();
  return RemoteSplashModel(id: id, version: '$id-${sha.substring(0, 16)}', videoUrl: videoUrl, videoSize: video.length,
    videoSha256: sha, imageUrl: imageUrl, imageSize: image.length, startDate: start, endDate: end);
}

void main() {
  late Directory root;
  late FakeRepo repo;
  late RemoteSplashService service;
  const String today = '2026-10-14';

  setUp(() {
    root = Directory.systemTemp.createTempSync('splash_test');
    repo = FakeRepo(root);
    service = RemoteSplashService(remoteSplashRepositoryInterface: repo);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('nothing downloaded → built-in splash', () {
    expect(service.playableSplash(today), isNull);
  });

  test('current splash is downloaded, verified and played', () async {
    final RemoteSplashModel a = splash(repo, 1, 'a');
    repo.info = RemoteSplashInfo(current: a);
    await service.sync(today);
    final StoredSplashModel? play = service.playableSplash(today);
    expect(play?.version, a.version);
    expect(File(play!.videoPath).existsSync(), isTrue);
    expect(File(play.imagePath).existsSync(), isTrue);
  });

  test('a damaged download is thrown away and never played', () async {
    repo.info = RemoteSplashInfo(current: splash(repo, 1, 'a', corrupt: true));
    await service.sync(today);
    expect(service.playableSplash(today), isNull);
    expect(root.listSync(), isEmpty);
  });

  test('replaced splash keeps playing until the new one has downloaded, then is deleted', () async {
    final RemoteSplashModel a = splash(repo, 1, 'a');
    repo.info = RemoteSplashInfo(current: a);
    await service.sync(today);
    final String oldVideo = service.playableSplash(today)!.videoPath;

    final RemoteSplashModel b = splash(repo, 2, 'b');
    repo.info = RemoteSplashInfo(current: b);
    repo.failingUrls.add(b.videoUrl!);
    await service.sync(today); // new one fails to download
    expect(service.playableSplash(today)?.version, a.version);
    expect(File(oldVideo).existsSync(), isTrue);

    repo.failingUrls.clear();
    await service.sync(today); // new one arrives
    expect(service.playableSplash(today)?.version, b.version);
    expect(File(oldVideo).existsSync(), isFalse);
  });

  test('finished campaign is deleted even when offline', () async {
    repo.info = RemoteSplashInfo(current: splash(repo, 1, 'a', end: '2026-10-15'));
    await service.sync(today);
    final String video = service.playableSplash(today)!.videoPath;

    repo.info = null; // offline
    await service.sync('2026-10-16');
    expect(service.playableSplash('2026-10-16'), isNull);
    expect(File(video).existsSync(), isFalse);
  });

  test('restore default (nothing offered) deletes the stored splash', () async {
    repo.info = RemoteSplashInfo(current: splash(repo, 1, 'a'));
    await service.sync(today);
    repo.info = RemoteSplashInfo();
    await service.sync(today);
    expect(service.playableSplash(today), isNull);
    expect(root.listSync(), isEmpty);
  });

  test('next campaign is downloaded early and plays from its start date', () async {
    final RemoteSplashModel a = splash(repo, 1, 'a', end: '2026-10-16');
    final RemoteSplashModel eid = splash(repo, 2, 'a', start: '2026-10-17', end: '2026-10-19'); // same video, own dates
    repo.info = RemoteSplashInfo(current: a, next: eid);
    await service.sync(today);
    expect(service.playableSplash(today)?.version, a.version);
    expect(service.playableSplash('2026-10-17')?.version, eid.version);
    expect(service.playableSplash('2026-10-20'), isNull);
  });

  test('date changes from the admin panel are picked up without downloading again', () async {
    final RemoteSplashModel a = splash(repo, 1, 'a');
    repo.info = RemoteSplashInfo(current: a);
    await service.sync(today);
    repo.failingUrls.addAll([a.videoUrl!, a.imageUrl!]); // any re-download would fail
    a.endDate = '2026-10-14';
    await service.sync(today);
    expect(service.playableSplash(today)?.version, a.version);
    expect(service.playableSplash('2026-10-15'), isNull);
  });

  const String api = String.fromEnvironment('SPLASH_TEST_API');
  test('real download from the local backend resumes and matches size + checksum', () async {
    final Map info = jsonDecode((await http.get(Uri.parse(api))).body);
    final RemoteSplashModel remote = RemoteSplashModel.fromJson(Map<String, dynamic>.from(info['current']));
    SharedPreferences.setMockInitialValues({});
    final RemoteSplashRepository real = RemoteSplashRepository(
      apiClient: ApiClient(appBaseUrl: 'http://127.0.0.1', sharedPreferences: await SharedPreferences.getInstance()),
      sharedPreferences: await SharedPreferences.getInstance());
    final File target = File('${root.path}/video.mp4');

    // Simulate an interrupted earlier session: the first 1 MB is already on the phone.
    final List<int> head = (await http.get(Uri.parse(remote.videoUrl!), headers: {'Range': 'bytes=0-1048575'})).bodyBytes;
    File('${target.path}.part').writeAsBytesSync(head);

    final bool ok = await real.download(remote.videoUrl!, target, expectedSize: remote.videoSize);
    expect(ok, isTrue);
    expect(target.lengthSync(), remote.videoSize);
    expect(await real.sha256Of(target), remote.videoSha256);
  }, skip: api.isEmpty ? 'pass --dart-define=SPLASH_TEST_API=… to run against the local backend' : false,
     timeout: const Timeout(Duration(minutes: 3)));
}
