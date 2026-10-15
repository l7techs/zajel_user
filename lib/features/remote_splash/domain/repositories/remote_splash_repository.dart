import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixam_mart/api/api_client.dart';
import 'package:sixam_mart/features/remote_splash/domain/models/remote_splash_model.dart';
import 'package:sixam_mart/features/remote_splash/domain/repositories/remote_splash_repository_interface.dart';
import 'package:sixam_mart/util/app_constants.dart';

class RemoteSplashRepository implements RemoteSplashRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  RemoteSplashRepository({required this.apiClient, required this.sharedPreferences});

  /// Small chunks with a short pause in between, so the splash download never competes with the
  /// menus and images the customer is looking at.
  static const Duration _chunkPause = Duration(milliseconds: 40);
  static const Duration _timeout = Duration(seconds: 30);

  @override
  Future<RemoteSplashInfo?> getSplashInfo() async {
    Response response = await apiClient.getData(AppConstants.remoteSplashUri, handleError: false);
    if (response.statusCode == 200 && response.body is Map) {
      final Map body = response.body;
      return RemoteSplashInfo(
        current: body['current'] is Map ? RemoteSplashModel.fromJson(Map<String, dynamic>.from(body['current'])) : null,
        next: body['next'] is Map ? RemoteSplashModel.fromJson(Map<String, dynamic>.from(body['next'])) : null,
      );
    }
    return null;
  }

  @override
  String? getStored() => sharedPreferences.getString(AppConstants.remoteSplashStored);

  @override
  Future<void> saveStored(String stored) async {
    await sharedPreferences.setString(AppConstants.remoteSplashStored, stored);
  }

  @override
  Future<Directory> splashDirectory(String version) async {
    final Directory base = await getApplicationSupportDirectory();
    final Directory dir = Directory('${base.path}/remote_splash/$version');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<bool> download(String url, File target, {int? expectedSize}) async {
    final File part = File('${target.path}.part');
    int have = part.existsSync() ? part.lengthSync() : 0;
    if (expectedSize != null && have > expectedSize) {
      await part.delete();
      have = 0;
    }
    if (expectedSize != null && have == expectedSize) {
      await part.rename(target.path);
      return true;
    }

    final http.Client client = http.Client();
    IOSink? sink;
    try {
      final http.Request request = http.Request('GET', Uri.parse(url));
      if (have > 0) {
        request.headers['Range'] = 'bytes=$have-';
      }
      final http.StreamedResponse response = await client.send(request).timeout(_timeout);
      final IOSink out;
      if (response.statusCode == 200) {
        have = 0; // the server ignored the range: start over
        out = part.openWrite(mode: FileMode.write);
      } else if (response.statusCode == 206) {
        out = part.openWrite(mode: FileMode.append);
      } else {
        return false;
      }
      sink = out;

      await for (final List<int> chunk in response.stream.timeout(_timeout)) {
        out.add(chunk);
        have += chunk.length;
        if (expectedSize != null && have > expectedSize) {
          await out.close();
          sink = null;
          await part.delete();
          return false;
        }
        await Future.delayed(_chunkPause);
      }
      await out.flush();
      await out.close();
      sink = null;

      if (expectedSize != null && have != expectedSize) {
        return false; // incomplete: keep the part file and resume next time
      }
      if (target.existsSync()) {
        await target.delete();
      }
      await part.rename(target.path);
      return true;
    } catch (_) {
      return false; // keep the part file; the next app session resumes it
    } finally {
      await sink?.close();
      client.close();
    }
  }

  @override
  Future<String> sha256Of(File file) async {
    final Digest digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  @override
  Future<void> deleteDirectoryOf(String path) async {
    try {
      final Directory dir = File(path).parent;
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  @override
  Future add(value) {
    throw UnimplementedError();
  }

  @override
  Future delete(int? id) {
    throw UnimplementedError();
  }

  @override
  Future get(String? id) {
    throw UnimplementedError();
  }

  @override
  Future getList({int? offset}) {
    throw UnimplementedError();
  }

  @override
  Future update(Map<String, dynamic> body, int? id) {
    throw UnimplementedError();
  }
}
