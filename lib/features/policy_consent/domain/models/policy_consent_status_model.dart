/// CUSTOM: customer policy consent (checklist 1.5 + 1.21) — GET /api/v1/customer/policy-consent
class PolicyConsentStatusModel {
  int? currentVersion;
  int? acceptedVersion;
  bool mustAccept;
  bool isUpdate;

  PolicyConsentStatusModel({this.currentVersion, this.acceptedVersion, this.mustAccept = false, this.isUpdate = false});

  factory PolicyConsentStatusModel.fromJson(Map<String, dynamic> json) {
    return PolicyConsentStatusModel(
      currentVersion: int.tryParse(json['current_version']?.toString() ?? ''),
      acceptedVersion: int.tryParse(json['accepted_version']?.toString() ?? ''),
      mustAccept: json['must_accept'] == true || json['must_accept'] == 1,
      isUpdate: json['is_update'] == true || json['is_update'] == 1,
    );
  }
}
