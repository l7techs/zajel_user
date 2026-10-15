import 'package:get/get.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/favourite/controllers/favourite_controller.dart';
import 'package:sixam_mart/features/home/controllers/home_controller.dart';
import 'package:sixam_mart/features/policy_consent/domain/models/policy_consent_status_model.dart';
import 'package:sixam_mart/features/policy_consent/domain/services/policy_consent_service_interface.dart';
import 'package:sixam_mart/features/policy_consent/screens/policy_consent_screen.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/rental_module/rental_cart_screen/controllers/taxi_cart_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';

/// CUSTOM: customer policy consent (SY-TPRA checklist 1.5 + 1.21).
/// A logged-in customer must have accepted the current privacy policy / terms version;
/// otherwise a blocking consent screen opens over the dashboard.
class PolicyConsentController extends GetxController implements GetxService {
  final PolicyConsentServiceInterface policyConsentServiceInterface;
  PolicyConsentController({required this.policyConsentServiceInterface});

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isScreenOpen = false;
  // The customer ticked the terms box on the sign-up form — record that as the first acceptance.
  bool _signUpAccepted = false;
  // Token already confirmed as up to date in this app run (avoids an API call on every dashboard rebuild).
  String? _checkedToken;

  void markSignUpAccepted() {
    _signUpAccepted = true;
  }

  Future<void> checkConsent() async {
    if (!AuthHelper.isLoggedIn() || _isScreenOpen) {
      return;
    }
    String token = Get.find<AuthController>().getUserToken();
    if (_checkedToken == token) {
      return;
    }

    PolicyConsentStatusModel? status = await policyConsentServiceInterface.getStatus();
    // No answer (offline / older backend): don't lock the customer out; check again on the next dashboard open.
    if (status == null || !AuthHelper.isLoggedIn()) {
      return;
    }
    if (!status.mustAccept) {
      _checkedToken = token;
      return;
    }
    if (_signUpAccepted && !status.isUpdate && await policyConsentServiceInterface.accept(isUpdate: false)) {
      _signUpAccepted = false;
      _checkedToken = token;
      return;
    }

    _isScreenOpen = true;
    await Get.to(() => PolicyConsentScreen(isUpdate: status.isUpdate), preventDuplicates: true);
    _isScreenOpen = false;
  }

  Future<void> accept({required bool isUpdate}) async {
    _isLoading = true;
    update();
    bool success = await policyConsentServiceInterface.accept(isUpdate: isUpdate);
    _isLoading = false;
    update();
    if (success) {
      _signUpAccepted = false;
      _checkedToken = Get.find<AuthController>().getUserToken();
      Get.back();
    } else {
      showCustomSnackBar('policy_consent_save_failed'.tr);
    }
  }

  /// Declining logs the customer out (same steps as the profile logout button).
  Future<void> decline() async {
    Get.find<AuthController>().resetOtpView();
    Get.find<ProfileController>().clearUserInfo();
    Get.find<AuthController>().socialLogout();
    Get.find<CartController>().clearCartList();
    Get.find<FavouriteController>().removeFavourite();
    await Get.find<AuthController>().clearSharedData();
    Get.find<HomeController>().forcefullyNullCashBackOffers();
    if (Get.find<SplashController>().module != null) {
      Get.find<TaxiCartController>().getCarCartList();
    }
    _signUpAccepted = false;
    _checkedToken = null;
    Get.offAllNamed(RouteHelper.getInitialRoute());
    showCustomSnackBar('logout_successful'.tr, isError: false);
  }
}
