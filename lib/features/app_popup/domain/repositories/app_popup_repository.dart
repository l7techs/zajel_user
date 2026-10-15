import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sixam_mart/api/api_client.dart';
import 'package:sixam_mart/features/app_popup/domain/models/app_popup_model.dart';
import 'package:sixam_mart/features/app_popup/domain/repositories/app_popup_repository_interface.dart';
import 'package:sixam_mart/util/app_constants.dart';

class AppPopupRepository implements AppPopupRepositoryInterface {
  final ApiClient apiClient;
  final SharedPreferences sharedPreferences;
  AppPopupRepository({required this.apiClient, required this.sharedPreferences});

  @override
  Future<AppPopupModel?> getPopup() async {
    Response response = await apiClient.getData(AppConstants.appPopupUri, handleError: false);
    if (response.statusCode == 200 && response.body is Map && response.body['popup'] != null) {
      return AppPopupModel.fromJson(response.body['popup']);
    }
    return null;
  }

  @override
  Future<void> sendView(int id) async {
    await apiClient.postData('${AppConstants.appPopupUri}/$id/view', {}, handleError: false);
  }

  @override
  Future<void> sendTap(int id) async {
    await apiClient.postData('${AppConstants.appPopupUri}/$id/tap', {}, handleError: false);
  }

  @override
  String? getShownDates() => sharedPreferences.getString(AppConstants.appPopupShown);

  @override
  Future<void> saveShownDates(String shownDates) async {
    await sharedPreferences.setString(AppConstants.appPopupShown, shownDates);
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
