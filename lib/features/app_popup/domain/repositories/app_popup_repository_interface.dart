import 'package:sixam_mart/features/app_popup/domain/models/app_popup_model.dart';
import 'package:sixam_mart/interfaces/repository_interface.dart';

abstract class AppPopupRepositoryInterface extends RepositoryInterface {
  Future<AppPopupModel?> getPopup();
  Future<void> sendView(int id);
  Future<void> sendTap(int id);
  /// JSON map: popup id → last date it was shown (yyyy-MM-dd)
  String? getShownDates();
  Future<void> saveShownDates(String shownDates);
}
