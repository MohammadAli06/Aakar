import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/commerce/domain/photo_enhancement.dart';
import 'api_client.dart';

final studioServiceProvider = Provider<StudioService>((ref) => StudioService());

class PreparedStudioPhoto {
  final String path, originalPath, provider;
  final bool reviewRequired;
  const PreparedStudioPhoto(
      this.path, this.originalPath, this.provider, this.reviewRequired);
}

/// Only this authenticated backend client handles OpenAI. No key in the app.
class StudioService {
  final ApiClient _api;
  StudioService({ApiClient? api}) : _api = api ?? apiClient;

  static bool isPhoto(String source) =>
      source.startsWith('/') ||
      source.contains(':\\') ||
      source.startsWith('http');

  Future<String> _localOriginal(String source) async {
    if (!source.startsWith('http')) return source;
    final uri = Uri.parse(source), backend = Uri.parse(ApiClient.baseUrl);
    final mediaPrefix = '${backend.path}/products/images/';
    // Never forward Firebase credentials to an arbitrary image host.
    if (uri.origin != backend.origin ||
        !uri.path.startsWith(mediaPrefix) ||
        !RegExp(r'^[a-f0-9]{32}\.jpg$')
            .hasMatch(uri.path.substring(mediaPrefix.length))) {
      throw ApiError(422,
          'Choose this photo again from your gallery to prepare it.', null);
    }
    final bytes = await _api.getBytes(uri.path.substring(backend.path.length));
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/studio-original-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  Future<PreparedStudioPhoto> prepare(String source, PhotoPrep mode,
      {bool catalogPlainBackground = true}) async {
    final original = await _localOriginal(source);
    final data = Map<String, dynamic>.from(await _api.uploadFile(
        '/studio/prepare', original,
        fields: {
          'mode': mode.name,
          'catalog_plain_background': catalogPlainBackground
        },
        receiveTimeout: const Duration(seconds: 210)) as Map);
    final bytes = base64Decode(data['image_base64'] as String);
    if (bytes.isEmpty || data['mime_type'] != 'image/jpeg') {
      throw ApiError(502, 'The backend returned no usable photo.', null);
    }
    final directory = await getApplicationDocumentsDirectory();
    final path =
        '${directory.path}/studio-${mode.name}-${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(path).writeAsBytes(bytes);
    return PreparedStudioPhoto(
        path, original, '${data['provider']}', data['review_required'] == true);
  }

  Future<Map<String, dynamic>> analyze(
      String original, String notes, String language) async {
    final path = await _localOriginal(original);
    return Map<String, dynamic>.from(await _api.uploadFile(
        '/studio/catalog', path,
        fields: {'notes': notes, 'language': language},
        receiveTimeout: const Duration(seconds: 210)) as Map);
  }
}

/// Existing artisan values, including deliberately cleared reviewed fields,
/// always win. New suggestions can only fill empty fields on initial review.
Map<String, dynamic> mergeCatalogSuggestions(
    Map<String, dynamic> draft, Map<String, dynamic> suggestions) {
  final result = Map<String, dynamic>.of(draft);
  for (final entry in suggestions.entries) {
    if (!const {
      'title',
      'title_hi',
      'description',
      'description_hi',
      'category',
      'material',
      'colour',
      'craft',
      'usage'
    }.contains(entry.key)) {
      continue;
    }
    final current = result[entry.key];
    if (current == null || (current is String && current.trim().isEmpty)) {
      result[entry.key] = entry.value;
    }
  }
  return result;
}
