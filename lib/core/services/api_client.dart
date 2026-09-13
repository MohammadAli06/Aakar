import 'package:dio/dio.dart';
import 'dart:typed_data';

import 'auth_service.dart';

/// Backend client.
///
/// The backend authenticates every request with the caller's Firebase ID token
/// (`Authorization: Bearer <idToken>`); there is no separate app-issued token.
/// The interceptor attaches a fresh token per request, so an expired token is
/// transparently refreshed by Firebase.
///
/// The default points at the project dev tunnel so a physical phone can reach
/// the backend. Override for another host, e.g. an emulator:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bsk08c2r-8000.inc1.devtunnels.ms/api/v1',
    //defaultValue: 'https://myaakar-8000.inc1.devtunnels.ms/api/v1',
  );

  final Dio _dio;

  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await idToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  static Future<String?> idToken({bool forceRefresh = false}) async {
    try {
      return await AuthService.idToken(forceRefresh: forceRefresh);
    } catch (_) {
      return null;
    }
  }

  /// Absolute URL for a stored media path.
  ///
  /// The backend answers with a path relative to the API (`/api/v1/...`) rather
  /// than an absolute URL, because the host it is reached through — a dev tunnel
  /// or a proxy — is not the host a client should later use. Resolve it against
  /// the base URL this build is already talking to.
  static String mediaUrl(String value) {
    if (!value.startsWith('/')) return value;
    try {
      return Uri.parse(baseUrl).origin + value;
    } catch (_) {
      return value;
    }
  }

  Future<dynamic> get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, e.response?.data);
    }
  }

  Future<dynamic> post(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response =
          await _dio.post(path, data: data, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, e.response?.data);
    }
  }

  Future<dynamic> put(String path,
      {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response =
          await _dio.put(path, data: data, queryParameters: queryParameters);
      return response.data;
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, e.response?.data);
    }
  }

  Future<dynamic> delete(String path, {dynamic data}) async {
    try {
      final response = await _dio.delete(path, data: data);
      return response.data;
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, e.response?.data);
    }
  }

  Future<dynamic> uploadFile(String path, String filePath,
      {Map<String, dynamic>? fields, Duration? receiveTimeout}) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        ...?fields,
      });
      final response = await _dio.post(path,
          data: form,
          options: Options(
              contentType: 'multipart/form-data',
              receiveTimeout: receiveTimeout));
      return response.data;
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, e.response?.data);
    }
  }

  Future<Uint8List> getBytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(path,
          options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(response.data ?? []);
    } on DioException catch (e) {
      throw ApiError(e.response?.statusCode ?? 0, e.message, null);
    }
  }
}

class ApiError implements Exception {
  final int statusCode;
  final String? message;
  final dynamic response;

  ApiError(this.statusCode, this.message, this.response);

  /// Human-readable backend detail (FastAPI returns `{"detail": "..."}`).
  String? get detail {
    final data = response;
    if (data is Map && data['detail'] != null) return '${data['detail']}';
    return null;
  }

  @override
  String toString() => detail ?? 'ApiError($statusCode): $message';
}

final apiClient = ApiClient();
