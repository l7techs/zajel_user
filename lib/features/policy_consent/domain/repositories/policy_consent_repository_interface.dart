import 'package:sixam_mart/features/policy_consent/domain/models/policy_consent_status_model.dart';
import 'package:sixam_mart/interfaces/repository_interface.dart';

abstract class PolicyConsentRepositoryInterface extends RepositoryInterface {
  /// null when the server can't answer (offline, or an older backend without the endpoint).
  Future<PolicyConsentStatusModel?> getStatus();
  Future<bool> accept(Map<String, dynamic> body);
}
