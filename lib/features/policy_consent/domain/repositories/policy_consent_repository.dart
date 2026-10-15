import 'package:get/get.dart';
import 'package:sixam_mart/api/api_client.dart';
import 'package:sixam_mart/features/policy_consent/domain/models/policy_consent_status_model.dart';
import 'package:sixam_mart/features/policy_consent/domain/repositories/policy_consent_repository_interface.dart';
import 'package:sixam_mart/util/app_constants.dart';

class PolicyConsentRepository implements PolicyConsentRepositoryInterface {
  final ApiClient apiClient;
  PolicyConsentRepository({required this.apiClient});

  @override
  Future<PolicyConsentStatusModel?> getStatus() async {
    Response response = await apiClient.getData(AppConstants.policyConsentUri, handleError: false);
    if (response.statusCode == 200 && response.body is Map) {
      return PolicyConsentStatusModel.fromJson(Map<String, dynamic>.from(response.body));
    }
    return null;
  }

  @override
  Future<bool> accept(Map<String, dynamic> body) async {
    Response response = await apiClient.postData(AppConstants.policyConsentUri, body, handleError: false);
    return response.statusCode == 200;
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
