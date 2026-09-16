import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:craft_connect/core/services/api_client.dart';
import 'package:craft_connect/core/services/studio_service.dart';
import 'package:craft_connect/features/commerce/domain/photo_enhancement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

class PhotoApi extends ApiClient {
  String mime = 'image/jpeg';
  final downloaded = <String>[];
  final uploaded = <String>[];

  @override
  Future<Uint8List> getBytes(String path) async {
    downloaded.add(path);
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<dynamic> uploadFile(String path, String filePath,
      {Map<String, dynamic>? fields, Duration? receiveTimeout}) async {
    expect(await File(filePath).readAsBytes(), [1, 2, 3]);
    uploaded.add(path);
    return path.endsWith('/prepare')
        ? {
            'image_base64': base64Encode([4, 5, 6]),
            'mime_type': mime,
            'provider': mime == 'image/png' ? 'cloudinary' : 'openai',
            'review_required': true,
          }
        : {
            'fields': {'title': 'Basket'}
          };
  }
}

void main() {
  test(
      'Catalog sends original photo bytes and notes through real multipart client',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('aakar-upload-test-');
    addTearDown(() => directory.delete(recursive: true));
    final original = File('${directory.path}/original.jpg');
    final bytes = base64Decode('/9j/2Q==');
    await original.writeAsBytes(bytes);
    final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl));
    addTearDown(() => dio.close(force: true));
    var uploads = 0;
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (request, handler) async {
      uploads++;
      expect(request.path, '/studio/catalog');
      expect(request.receiveTimeout, const Duration(seconds: 210));
      expect(request.contentType, 'multipart/form-data');
      final form = request.data as FormData;
      expect(Map.fromEntries(form.fields),
          {'notes': 'Handmade basket', 'language': 'hi'});
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'original.jpg');
      expect(
          await form.files.single.value
              .finalize()
              .expand((chunk) => chunk)
              .toList(),
          bytes);
      handler.resolve(Response(requestOptions: request, statusCode: 200, data: {
        'fields': {'title': 'Basket'}
      }));
    }));
    final service = StudioService(api: ApiClient(dio: dio));
    final result =
        await service.analyze(original.path, 'Handmade basket', 'hi');
    expect(result['fields']['title'], 'Basket');
    expect(uploads, 1);
  });

  test('Catalog preserves specific backend provider errors', () async {
    final directory =
        await Directory.systemTemp.createTemp('aakar-error-test-');
    addTearDown(() => directory.delete(recursive: true));
    final file =
        await File('${directory.path}/original.jpg').writeAsBytes([1, 2]);
    final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl));
    addTearDown(() => dio.close(force: true));
    const detail =
        'gemini upstream HTTP 403: denied permission for this request.';
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      handler.reject(DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response(
              requestOptions: request,
              statusCode: 502,
              data: {'detail': detail})));
    }));
    await expectLater(
        StudioService(api: ApiClient(dio: dio)).analyze(file.path, '', 'en'),
        throwsA(isA<ApiError>()
            .having((error) => error.toString(), 'detail', detail)));
  });

  test('Cloudinary PNG preview keeps its extension and review requirement',
      () async {
    final directory = await Directory.systemTemp.createTemp('aakar-png-test-');
    addTearDown(() => directory.delete(recursive: true));
    final api = PhotoApi()..mime = 'image/png';
    final service =
        StudioService(api: api, documentsDirectory: () async => directory);
    final result = await service.prepare(
        '/api/v1/products/images/0123456789abcdef0123456789abcdef.jpg',
        PhotoPrep.plainBackground);
    expect(result.path, endsWith('.png'));
    expect(result.provider, 'cloudinary');
    expect(result.reviewRequired, isTrue);
    expect(await File(result.path).readAsBytes(), [4, 5, 6]);
  });

  test('Saved relative and absolute photos download before Studio uploads',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('aakar-studio-test-');
    addTearDown(() => directory.delete(recursive: true));
    final api = PhotoApi();
    final service =
        StudioService(api: api, documentsDirectory: () async => directory);
    const path = '/api/v1/products/images/0123456789abcdef0123456789abcdef.jpg';
    final prepared = await service.prepare(path, PhotoPrep.plainBackground);
    expect(await File(prepared.path).readAsBytes(), [4, 5, 6]);
    expect(
        (await service.analyze(path, '', 'en'))['fields']['title'], 'Basket');
    await service.analyze(ApiClient.mediaUrl(path), '', 'en');
    expect(api.downloaded, List.filled(3, path.substring('/api/v1'.length)));
    expect(api.uploaded,
        ['/studio/prepare', '/studio/catalog', '/studio/catalog']);
  });

  test(
      'Studio refuses unrelated remote media before making authenticated requests',
      () async {
    final api = PhotoApi();
    final service = StudioService(api: api);
    for (final path in [
      'https://example.com/photo.jpg',
      '/api/v1/auth/private.jpg'
    ]) {
      await expectLater(
          service.analyze(path, '', 'en'), throwsA(isA<ApiError>()));
    }
    expect(api.downloaded, isEmpty);
    expect(api.uploaded, isEmpty);
  });

  test(
      'Suggestions fill gaps without replacing artisan values or business data',
      () {
    final draft = {
      'title': 'My chosen name',
      'material': '',
      'stock': 0,
      'customizable': false
    };
    final merged = mergeCatalogSuggestions(draft, {
      'title': 'Model name',
      'material': 'Bamboo',
      'colour': 'Brown',
      'price': 500,
      'approved': true
    });
    expect(merged, {
      'title': 'My chosen name',
      'material': 'Bamboo',
      'colour': 'Brown',
      'stock': 0,
      'customizable': false
    });
    expect(draft['material'], '');
  });
}
