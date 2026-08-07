import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

final cloudinaryServiceProvider = Provider((ref) => CloudinaryService());

class CloudinaryService {
  static const String _defaultCloudName = 'dqrrzwb59';
  static const String _defaultUploadPreset = 'unsigned_preset';

  final String cloudName = const String.fromEnvironment(
    'SPENDLY_CLOUDINARY_CLOUD_NAME',
    defaultValue: _defaultCloudName,
  );

  final String uploadPreset = const String.fromEnvironment(
    'SPENDLY_CLOUDINARY_UPLOAD_PRESET',
    defaultValue: _defaultUploadPreset,
  );

  Future<String?> uploadImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return _uploadBytes(
      bytes,
      filename: imageFile.uri.pathSegments.isEmpty
          ? 'spendly-image.jpg'
          : imageFile.uri.pathSegments.last,
    );
  }

  Future<String?> uploadXFile(XFile imageFile) async {
    return _uploadBytes(
      await imageFile.readAsBytes(),
      filename: imageFile.name,
    );
  }

  Future<String?> _uploadBytes(
    Uint8List bytes, {
    required String filename,
  }) async {
    if (uploadPreset.trim().isEmpty) {
      debugPrint(
        'Cloudinary upload preset is empty. Set SPENDLY_CLOUDINARY_UPLOAD_PRESET.',
      );
      return _inlineImageDataUrl(bytes, filename);
    }
    if (cloudName.trim().isEmpty) {
      debugPrint(
        'Cloudinary cloud name is empty. Set SPENDLY_CLOUDINARY_CLOUD_NAME.',
      );
      return _inlineImageDataUrl(bytes, filename);
    }

    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest("POST", url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

    late final http.StreamedResponse streamedResponse;
    late final String body;
    try {
      streamedResponse = await request.send();
      body = await streamedResponse.stream.bytesToString();
    } catch (e) {
      debugPrint('Cloudinary upload request failed: $e');
      return _inlineImageDataUrl(bytes, filename);
    }

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      debugPrint(
        'Cloudinary upload failed (${streamedResponse.statusCode}). Body: $body',
      );
      return _inlineImageDataUrl(bytes, filename);
    }

    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final secureUrl = data['secure_url'] as String?;
      if (secureUrl == null || secureUrl.isEmpty) {
        debugPrint(
          'Cloudinary upload succeeded but secure_url is missing. Body: $body',
        );
        return _inlineImageDataUrl(bytes, filename);
      }
      return secureUrl;
    } catch (e) {
      debugPrint('Cloudinary response parse error: $e. Body: $body');
      return _inlineImageDataUrl(bytes, filename);
    }
  }

  String _inlineImageDataUrl(Uint8List bytes, String filename) {
    final extension = filename.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }
}
