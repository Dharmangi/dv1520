import '../../core/network/api_client.dart';
import '../models/app_version_info.dart';

/// Wraps the raw network call for fetching the latest published app version,
/// keeping UpdateService free of direct ApiClient/Dio knowledge.
class UpdateRepository {
  Future<AppVersionInfo> fetchLatestVersion() async {
    final res = await ApiClient.instance.dio.get('/version');
    return AppVersionInfo.fromJson(res.data as Map<String, dynamic>);
  }
}
