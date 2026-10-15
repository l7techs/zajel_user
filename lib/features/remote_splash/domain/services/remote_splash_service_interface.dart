import 'package:sixam_mart/features/remote_splash/domain/models/remote_splash_model.dart';

abstract class RemoteSplashServiceInterface {
  /// The downloaded splash to play today, or null (= use the splash built into the app).
  StoredSplashModel? playableSplash(String today);

  /// Ask the server, download what is offered, verify it, and clean up old splashes.
  Future<void> sync(String today);

  /// A downloaded splash that failed to play: delete it so the app falls back to the built-in one.
  Future<void> discard(String version);
}
