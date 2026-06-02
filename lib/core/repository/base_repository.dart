import '../services/api_service.dart';
import '../utils/app_constant.dart';

abstract class BaseRepository {
  final ApiClient apiClient;

  BaseRepository({ApiClient? apiClient}) : apiClient = apiClient ?? ApiClient();

  String getFullUrl(String endpoint) {
    return '$baseUrl$endpoint';
  }
}
