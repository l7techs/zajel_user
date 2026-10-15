import 'package:get/get.dart';
import 'package:sixam_mart/features/policy_consent/domain/models/policy_consent_status_model.dart';
import 'package:sixam_mart/features/policy_consent/domain/repositories/policy_consent_repository_interface.dart';
import 'package:sixam_mart/features/policy_consent/domain/services/policy_consent_service_interface.dart';
import 'package:sixam_mart/util/app_constants.dart';

class PolicyConsentService implements PolicyConsentServiceInterface {
  final PolicyConsentRepositoryInterface policyConsentRepositoryInterface;
  PolicyConsentService({required this.policyConsentRepositoryInterface});

  @override
  Future<PolicyConsentStatusModel?> getStatus() async {
    return await policyConsentRepositoryInterface.getStatus();
  }

  @override
  Future<bool> accept({required bool isUpdate}) async {
    return await policyConsentRepositoryInterface.accept({
      'context': isUpdate ? 'update' : 'sign_up',
      'platform': GetPlatform.isWeb ? 'web' : GetPlatform.isIOS ? 'ios' : GetPlatform.isAndroid ? 'android' : 'other',
      'app_version': AppConstants.appVersion.toString(),
    });
  }
}
