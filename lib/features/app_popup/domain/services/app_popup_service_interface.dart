import 'package:sixam_mart/features/app_popup/domain/models/app_popup_model.dart';

abstract class AppPopupServiceInterface {
  Future<AppPopupModel?> getPopup();
  /// Whether the popup may be shown today, by its frequency and when this device last showed it.
  bool shouldShow(AppPopupModel popup, String today);
  Future<void> markShown(int id, String today);
  Future<void> sendView(int id);
  Future<void> sendTap(int id);
}
