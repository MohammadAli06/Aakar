import 'package:dio/dio.dart';

class ApiClient {
  // Dev tunnel URL - replace with your permanent tunnel name when ready
  static const String baseUrl = 'https://myaakar-8000.inc1.devtunnels.ms/api/v1';

  final Dio _dio;

  ApiClient()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ));

  // Add auth token to requests
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // Clear auth token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  // Generic GET request
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, e.response?.data);
    }
  }

  // Generic POST request
  Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final response = await _dio.post(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, e.response?.data);
    }
  }

  // Generic PUT request
  Future<dynamic> put(String path, {dynamic data}) async {
    try {
      final response = await _dio.put(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, e.response?.data);
    }
  }

  // Generic DELETE request
  Future<dynamic> delete(String path, {dynamic data}) async {
    try {
      final response = await _dio.delete(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, e.response?.data);
    }
  }

  // Upload file (for product photos)
  Future<dynamic> uploadFile(String path, String filePath, {Map<String, dynamic>? fields}) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        ...?fields,
      });
      final response = await _dio.post(path, data: form);
      return response.data;
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, e.response?.data);
    }
  }
}

class ApiError implements Exception {
  final int statusCode;
  final String? message;
  final dynamic response;

  ApiError(this.statusCode, this.message, this.response);

  @override
  String toString() => 'ApiError($statusCode): $message';
}

// Singleton instance
final apiClient = ApiClient();
