class AppVersionInfo {
  AppVersionInfo({
    required this.version,
    required this.apkUrl,
    required this.forceUpdate,
    required this.releaseNotes,
  });

  final String version;
  final String apkUrl;
  final bool forceUpdate;
  final String releaseNotes;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
        version: json['version'] as String,
        apkUrl: json['apkUrl'] as String,
        forceUpdate: json['forceUpdate'] as bool? ?? false,
        releaseNotes: json['releaseNotes'] as String? ?? '',
      );
}
