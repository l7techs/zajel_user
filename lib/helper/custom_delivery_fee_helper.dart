import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';

/// CUSTOM: "Base fee + per km" delivery charge model (zone module `delivery_charge_type` = `base_per_km`).
/// Mirrors the backend `app/CentralLogics/CustomDeliveryFeeLogic.php` so the checkout preview equals the charged fee.
/// Plan: docs/plan-delivery-fee-base-per-km.md
class CustomDeliveryFeeHelper {
  static const String basePerKmType = 'base_per_km';

  static bool isBasePerKm(Pivot? pivot) => pivot?.deliveryChargeType == basePerKmType;

  /// Distance rounded UP to a whole km: 0.1 → 1, 1.0 → 1, 1.02 → 2.
  static int chargedKm(double distanceKm) {
    final double clean = double.parse((distanceKm < 0 ? 0 : distanceKm).toStringAsFixed(6));
    return clean.ceil();
  }

  /// Base fee + extra km, capped by the maximum. Vehicle extra, surge and rounding are added by the caller.
  static double cappedFee(double distanceKm, Pivot pivot) {
    final double baseFee = pivot.minimumShippingCharge ?? 0;
    final double perKm = pivot.perKmShippingCharge ?? 0;
    final double includedKm = pivot.includedKm ?? 1;
    final double maximum = pivot.maximumShippingCharge ?? 0;

    double extraKm = chargedKm(distanceKm) - includedKm;
    if (extraKm < 0) extraKm = 0;
    double fee = baseFee + extraKm * perKm;

    if (maximum > 0 && maximum >= baseFee && fee > maximum) {
      fee = maximum;
    }
    return fee;
  }

  /// Rounds the final delivery fee UP to the nearest step when rounding is on.
  static double roundFee(double fee, Pivot pivot) {
    final double step = pivot.feeRoundingStep ?? 0;
    if (pivot.feeRoundingStatus != true || step <= 0 || fee <= 0) {
      return fee;
    }
    final double steps = double.parse((fee / step).toStringAsFixed(6));
    return steps.ceil() * step;
  }
}
