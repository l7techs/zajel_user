import 'dart:io';

import 'package:sixam_mart/features/remote_splash/domain/models/remote_splash_model.dart';
import 'package:sixam_mart/interfaces/repository_interface.dart';

abstract class RemoteSplashRepositoryInterface extends RepositoryInterface {
  /// null when the server could not be reached (or has no splash module yet).
  Future<RemoteSplashInfo?> getSplashInfo();

  /// JSON list of [StoredSplashModel]s kept on the phone.
  String? getStored();
  Future<void> saveStored(String stored);

  /// Folder for one splash version's files (created if missing).
  Future<Directory> splashDirectory(String version);

  /// Downloads [url] into [target] in small, paced chunks, resuming a partial file. Returns false on failure.
  Future<bool> download(String url, File target, {int? expectedSize});

  /// Lower-case hex SHA-256 of a file.
  Future<String> sha256Of(File file);

  Future<void> deleteDirectoryOf(String path);
}
