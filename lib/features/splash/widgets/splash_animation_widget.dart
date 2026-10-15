import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/features/remote_splash/controllers/remote_splash_controller.dart';
import 'package:sixam_mart/features/remote_splash/domain/models/remote_splash_model.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:video_player/video_player.dart';

/// Full-screen mascot animation for the splash screen, played once (it holds its last frame).
/// Plays the splash downloaded from the admin panel (features/remote_splash) when one is ready for today,
/// otherwise the one built into the app. Shows the first frame as a still until the video is playing, and keeps
/// the still if the video cannot be played (unsupported codec, web autoplay block, …); a downloaded video that
/// fails is deleted and the built-in one is played instead.
/// Tells [SplashController] when the video has played to the end so the splash does not
/// leave before the animation has been seen.
class SplashAnimationWidget extends StatefulWidget {
  const SplashAnimationWidget({super.key});

  @override
  State<SplashAnimationWidget> createState() => _SplashAnimationWidgetState();
}

class _SplashAnimationWidgetState extends State<SplashAnimationWidget> {
  late VideoPlayerController _controller;
  StoredSplashModel? _remote;
  bool _playing = false;
  bool _fallingBack = false;
  Timer? _loopTimer;

  @override
  void initState() {
    super.initState();
    Get.find<SplashController>().resetSplashAnimationGate();
    _remote = Get.find<RemoteSplashController>().playableSplash();
    _controller = _createController();
    _controller.addListener(_onVideoUpdate);
    _startVideo();
  }

  VideoPlayerController _createController() {
    final VideoPlayerOptions options = VideoPlayerOptions(mixWithOthers: true);
    return _remote != null
        ? VideoPlayerController.file(File(_remote!.videoPath), videoPlayerOptions: options)
        : VideoPlayerController.asset(Images.splashAnimation, videoPlayerOptions: options);
  }

  Future<void> _startVideo() async {
    final VideoPlayerController controller = _controller;
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(false); // plays once; holds the last frame if loading takes longer
      await controller.play();
    } catch (_) {
      if (controller != _controller || _fallingBack) {
        return; // being replaced by the built-in video
      }
      if (_remote != null) {
        await _fallBackToBuiltIn();
      } else {
        // Keep showing the still frame and let the splash continue.
        Get.find<SplashController>().openSplashAnimationGate();
      }
    }
  }

  /// The downloaded video could not be played: delete it and play the built-in splash.
  Future<void> _fallBackToBuiltIn() async {
    if (_remote == null) {
      return; // already falling back
    }
    final String version = _remote!.version;
    _fallingBack = true;
    _remote = null;
    _controller.removeListener(_onVideoUpdate);
    await _controller.dispose();
    Get.find<RemoteSplashController>().discard(version);
    if (!mounted) {
      return;
    }
    setState(() {
      _playing = false;
      _controller = _createController();
    });
    _fallingBack = false;
    _controller.addListener(_onVideoUpdate);
    await _startVideo();
  }

  void _onVideoUpdate() {
    final VideoPlayerValue value = _controller.value;
    if (value.hasError) {
      if (_remote != null) {
        _fallBackToBuiltIn();
      } else {
        Get.find<SplashController>().openSplashAnimationGate();
      }
      return;
    }
    if (!_playing && value.isInitialized && value.isPlaying && mounted) {
      setState(() => _playing = true);
      _loopTimer = Timer(value.duration, () => Get.find<SplashController>().openSplashAnimationGate());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Once the next screen is pushed, stop decoding so the transition and the
    // home screen build get the CPU/GPU; the current frame stays on screen.
    if (ModalRoute.of(context)?.isCurrent == false && _controller.value.isPlaying) {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    Get.find<SplashController>().openSplashAnimationGate();
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      _remote != null
          ? Image.file(File(_remote!.imagePath), fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Image.asset(Images.splashFirstFrame, fit: BoxFit.cover))
          : Image.asset(Images.splashFirstFrame, fit: BoxFit.cover),

      if (_playing)
        FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
    ]);
  }
}
