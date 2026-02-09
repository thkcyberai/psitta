import 'package:dio/dio.dart';
import '../../core/constants.dart';

class ApiClient {
  late final Dio _dio;
  ApiClient() { _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: AppConstants.httpTimeout,
    receiveTimeout: AppConstants.httpTimeout)); }
  Dio get dio => _dio;
}
