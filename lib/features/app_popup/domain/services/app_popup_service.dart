import 'dart:convert';

import 'package:sixam_mart/features/app_popup/domain/models/app_popup_model.dart';
import 'package:sixam_mart/features/app_popup/domain/repositories/app_popup_repository_interface.dart';
import 'package:sixam_mart/features/app_popup/domain/services/app_popup_service_interface.dart';
import 'package:sixam_mart/util/app_constants.dart';

class AppPopupService implements AppPopupServiceInterface {
  final AppPopupRepositoryInterface appPopupRepositoryInterface;
  AppPopupService({required this.appPopupRepositoryInterface});

  @override
  Future<AppPopupModel?> getPopup() async {
    return await appPopupRepositoryInterface.getPopup();
  }

  @override
  bool shouldShow(AppPopupModel popup, String today) {
    if (popup.id == null) {
      return false;
    }
    String? lastShown = _getShownDates()[popup.id.toString()];
    switch (popup.frequency) {
      case 'always':
        return true;
      case 'daily':
        return lastShown != today;
      default:
        return lastShown == null;
    }
  }

  @override
  Future<void> markShown(int id, String today) async {
    Map<String, String> shownDates = _getShownDates();
    shownDates.remove(id.toString());
    shownDates[id.toString()] = today;
    // Keep only the most recent popups.
    while (shownDates.length > AppConstants.appPopupShownLimit) {
      shownDates.remove(shownDates.keys.first);
    }
    await appPopupRepositoryInterface.saveShownDates(jsonEncode(shownDates));
  }

  /// popup id → last date it was shown on this device
  Map<String, String> _getShownDates() {
    String? raw = appPopupRepositoryInterface.getShownDates();
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(raw)).map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> sendView(int id) async {
    await appPopupRepositoryInterface.sendView(id);
  }

  @override
  Future<void> sendTap(int id) async {
    await appPopupRepositoryInterface.sendTap(id);
  }
}
