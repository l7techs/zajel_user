import 'package:sixam_mart/features/policy_consent/domain/models/policy_consent_status_model.dart';

abstract class PolicyConsentServiceInterface {
  Future<PolicyConsentStatusModel?> getStatus();
  /// [isUpdate] true = re-acceptance after a new policy version, false = first acceptance (sign-up).
  Future<bool> accept({required bool isUpdate});
}
