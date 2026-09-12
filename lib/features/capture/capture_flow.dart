import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'in_app_camera_screen.dart';
import 'selfie_camera_screen.dart';

Future<String?> _persist(String source, String prefix) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final saved = await File(source).copy(
        '${directory.path}/$prefix-${DateTime.now().microsecondsSinceEpoch}.jpg');
    return saved.path;
  } catch (_) {
    // The captured file is still valid even if copying fails.
    return source;
  }
}

/// Opens the in-app product camera. Returns a saved file path, or null if the
/// user cancelled. The device's own camera app is never launched.
Future<String?> captureProductPhoto(BuildContext context) async {
  final path = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const InAppCameraScreen()),
  );
  if (path == null) return null;
  return _persist(path, 'product');
}

/// Opens the in-app selfie camera with face guidance. Returns a saved file path,
/// or null if the user cancelled.
Future<String?> captureSelfie(BuildContext context) async {
  final path = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const SelfieCameraScreen()),
  );
  if (path == null) return null;
  return _persist(path, 'selfie');
}
