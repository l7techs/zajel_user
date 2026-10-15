/// A splash offered by the server (GET /api/v1/app-splash → "current" / "next").
class RemoteSplashModel {
  int? id;
  String? version;
  String? videoUrl;
  int? videoSize;
  String? videoSha256;
  String? imageUrl;
  int? imageSize;
  int? durationMs;
  String? startDate;
  String? endDate;

  RemoteSplashModel({this.id, this.version, this.videoUrl, this.videoSize, this.videoSha256,
    this.imageUrl, this.imageSize, this.durationMs, this.startDate, this.endDate,
  });

  RemoteSplashModel.fromJson(Map<String, dynamic> json) {
    id = int.tryParse(json['id']?.toString() ?? '');
    version = json['version']?.toString();
    videoUrl = json['video_url']?.toString();
    videoSize = int.tryParse(json['video_size']?.toString() ?? '');
    videoSha256 = json['video_sha256']?.toString();
    imageUrl = json['image_url']?.toString();
    imageSize = int.tryParse(json['image_size']?.toString() ?? '');
    durationMs = int.tryParse(json['duration_ms']?.toString() ?? '');
    startDate = json['start_date']?.toString();
    endDate = json['end_date']?.toString();
  }

  /// Everything needed to download and check it.
  bool get isComplete => version != null && version!.isNotEmpty && videoUrl != null && imageUrl != null
      && (videoSize ?? 0) > 0 && (videoSha256?.length ?? 0) == 64;
}

/// A splash kept on the phone. [ready] = both files downloaded and checked.
class StoredSplashModel {
  String version;
  String? startDate;
  String? endDate;
  String videoPath;
  String imagePath;
  bool ready;

  StoredSplashModel({required this.version, this.startDate, this.endDate, required this.videoPath,
    required this.imagePath, this.ready = false,
  });

  factory StoredSplashModel.fromJson(Map<String, dynamic> json) => StoredSplashModel(
    version: json['version']?.toString() ?? '',
    startDate: json['start_date']?.toString(),
    endDate: json['end_date']?.toString(),
    videoPath: json['video_path']?.toString() ?? '',
    imagePath: json['image_path']?.toString() ?? '',
    ready: json['ready'] == true,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'start_date': startDate,
    'end_date': endDate,
    'video_path': videoPath,
    'image_path': imagePath,
    'ready': ready,
  };
}

/// Server answer: the running splash and the next scheduled one (either may be null).
class RemoteSplashInfo {
  final RemoteSplashModel? current;
  final RemoteSplashModel? next;
  RemoteSplashInfo({this.current, this.next});

  List<RemoteSplashModel> get offered {
    final List<RemoteSplashModel> list = [];
    for (final RemoteSplashModel? splash in [current, next]) {
      if (splash != null && splash.isComplete && !list.any((s) => s.version == splash.version)) {
        list.add(splash);
      }
    }
    return list;
  }
}
