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

  /// Splits [releaseNotes] into individual bullet lines, dropping any leading
  /// bullet glyph the source text may already have (e.g. GitHub's generated
  /// notes prefix each line with "* "), and dropping GitHub's trailing
  /// "**Full Changelog**: <link>" line, which isn't meaningful to end users.
  List<String> get releaseNotesLines => releaseNotes
      .split('\n')
      .map((line) => line.trim().replaceFirst(RegExp(r'^[•*-]\s*'), ''))
      .where((line) => line.isNotEmpty)
      .where((line) => !line.toLowerCase().startsWith('*full changelog*'))
      .toList();

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
        version: json['version'] as String,
        apkUrl: json['apkUrl'] as String,
        forceUpdate: json['forceUpdate'] as bool? ?? false,
        releaseNotes: json['releaseNotes'] as String? ?? '',
      );
}
