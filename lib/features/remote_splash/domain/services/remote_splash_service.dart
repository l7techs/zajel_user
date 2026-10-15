import 'dart:convert';
import 'dart:io';

import 'package:sixam_mart/features/remote_splash/domain/models/remote_splash_model.dart';
import 'package:sixam_mart/features/remote_splash/domain/repositories/remote_splash_repository_interface.dart';
import 'package:sixam_mart/features/remote_splash/domain/services/remote_splash_service_interface.dart';

/// Rules (dates are yyyy-MM-dd strings, so they compare as text):
/// - play a stored splash only when it is ready, its files exist and today is inside its dates;
/// - download what the server offers ("current" and "next") into a temp file, check size + SHA-256, then mark it ready;
/// - delete a stored splash when its end date has passed, or when the server no longer offers it AND everything
///   the server offers is ready (so a replaced splash keeps playing until its replacement has downloaded).
class RemoteSplashService implements RemoteSplashServiceInterface {
  final RemoteSplashRepositoryInterface remoteSplashRepositoryInterface;
  RemoteSplashService({required this.remoteSplashRepositoryInterface});

  List<StoredSplashModel> _readStored() {
    final String? raw = remoteSplashRepositoryInterface.getStored();
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      return (jsonDecode(raw) as List).map((e) => StoredSplashModel.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeStored(List<StoredSplashModel> stored) async {
    await remoteSplashRepositoryInterface.saveStored(jsonEncode(stored.map((s) => s.toJson()).toList()));
  }

  bool _inDates(String? start, String? end, String today) {
    return (start == null || start.compareTo(today) <= 0) && (end == null || end.compareTo(today) >= 0);
  }

  bool _expired(String? end, String today) => end != null && end.compareTo(today) < 0;

  @override
  StoredSplashModel? playableSplash(String today) {
    for (final StoredSplashModel splash in _readStored()) {
      if (splash.ready && _inDates(splash.startDate, splash.endDate, today)
          && File(splash.videoPath).existsSync() && File(splash.imagePath).existsSync()) {
        return splash;
      }
    }
    return null;
  }

  @override
  Future<void> sync(String today) async {
    List<StoredSplashModel> stored = _readStored();

    // 1. Campaigns that have finished.
    for (final StoredSplashModel splash in stored.where((s) => _expired(s.endDate, today)).toList()) {
      await remoteSplashRepositoryInterface.deleteDirectoryOf(splash.videoPath);
      stored.remove(splash);
    }
    await _writeStored(stored);

    final RemoteSplashInfo? info = await remoteSplashRepositoryInterface.getSplashInfo();
    if (info == null) {
      return; // offline or no splash module on the server: keep what we have
    }
    final List<RemoteSplashModel> offered = info.offered.where((s) => !_expired(s.endDate, today)).toList();

    // 2. Download what is offered and not ready yet; refresh the dates of what we already have.
    bool allReady = true;
    for (final RemoteSplashModel remote in offered) {
      StoredSplashModel? local = stored.firstWhereOrNull((s) => s.version == remote.version);
      if (local != null && local.ready) {
        local.startDate = remote.startDate;
        local.endDate = remote.endDate;
        continue;
      }
      final bool ok = await _downloadAndVerify(remote, local, stored);
      allReady = allReady && ok;
    }
    await _writeStored(stored);

    // 3. Replaced or turned off: remove once everything offered is on the phone.
    if (allReady) {
      final Set<String> offeredVersions = offered.map((s) => s.version!).toSet();
      for (final StoredSplashModel splash in stored.where((s) => !offeredVersions.contains(s.version)).toList()) {
        await remoteSplashRepositoryInterface.deleteDirectoryOf(splash.videoPath);
        stored.remove(splash);
      }
      await _writeStored(stored);
    }
  }

  Future<bool> _downloadAndVerify(RemoteSplashModel remote, StoredSplashModel? local, List<StoredSplashModel> stored) async {
    final Directory dir = await remoteSplashRepositoryInterface.splashDirectory(remote.version!);
    final String imageExt = remote.imageUrl!.split('?').first.split('.').last.toLowerCase();
    final File video = File('${dir.path}/video.mp4');
    final File image = File('${dir.path}/still.${imageExt.length <= 4 ? imageExt : 'img'}');

    if (local == null) {
      local = StoredSplashModel(version: remote.version!, startDate: remote.startDate, endDate: remote.endDate,
        videoPath: video.path, imagePath: image.path);
      stored.add(local);
      await _writeStored(stored);
    }

    final bool imageOk = image.existsSync()
        || await remoteSplashRepositoryInterface.download(remote.imageUrl!, image,
            expectedSize: (remote.imageSize ?? 0) > 0 ? remote.imageSize : null);
    if (!imageOk) {
      return false;
    }
    final bool videoOk = video.existsSync() || await remoteSplashRepositoryInterface.download(remote.videoUrl!, video, expectedSize: remote.videoSize);
    if (!videoOk) {
      return false;
    }

    if (video.lengthSync() != remote.videoSize || await remoteSplashRepositoryInterface.sha256Of(video) != remote.videoSha256!.toLowerCase()) {
      // Damaged: throw it away and try again next session.
      await remoteSplashRepositoryInterface.deleteDirectoryOf(video.path);
      stored.remove(local);
      return false;
    }

    local.startDate = remote.startDate;
    local.endDate = remote.endDate;
    local.ready = true;
    return true;
  }

  @override
  Future<void> discard(String version) async {
    final List<StoredSplashModel> stored = _readStored();
    final StoredSplashModel? splash = stored.firstWhereOrNull((s) => s.version == version);
    if (splash != null) {
      await remoteSplashRepositoryInterface.deleteDirectoryOf(splash.videoPath);
      stored.remove(splash);
      await _writeStored(stored);
    }
  }
}

extension _FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final T element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
