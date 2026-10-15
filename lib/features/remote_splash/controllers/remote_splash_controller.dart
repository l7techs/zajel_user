import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/remote_splash/domain/models/remote_splash_model.dart';
import 'package:sixam_mart/features/remote_splash/domain/services/remote_splash_service_interface.dart';
import 'package:sixam_mart/helper/date_converter.dart';

/// Splash videos managed from the admin panel (Modules/AppSplash). The splash screen asks [playableSplash] at launch;
/// the dashboard calls [scheduleSync] once the home screen has loaded, and the download happens quietly in the
/// background for the next launch.
class RemoteSplashController extends GetxController implements GetxService {
  final RemoteSplashServiceInterface remoteSplashServiceInterface;
  RemoteSplashController({required this.remoteSplashServiceInterface});

  /// Wait after the home screen has loaded before touching the network, so its data and images go first.
  static const Duration _startDelay = Duration(seconds: 10);

  bool _syncStarted = false;

  String get _today => DateConverter.dateToDate(DateTime.now());

  StoredSplashModel? playableSplash() {
    if (kIsWeb) {
      return null;
    }
    try {
      return remoteSplashServiceInterface.playableSplash(_today);
    } catch (_) {
      return null;
    }
  }

  /// Once per app session.
  void scheduleSync() {
    if (kIsWeb || _syncStarted) {
      return;
    }
    _syncStarted = true;
    Timer(_startDelay, () async {
      try {
        await remoteSplashServiceInterface.sync(_today);
      } catch (_) {
        // Never let the splash download disturb the app; it simply retries next session.
      }
    });
  }

  Future<void> discard(String version) async {
    try {
      await remoteSplashServiceInterface.discard(version);
    } catch (_) {}
  }
}
