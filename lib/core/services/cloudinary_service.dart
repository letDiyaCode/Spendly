import 'dart:convert';
import 'dart:io';

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
    return _uploadMultipart(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );
  }

  Future<String?> uploadXFile(XFile imageFile) async {
    return _uploadMultipart(
      http.MultipartFile.fromBytes(
        'file',
        await imageFile.readAsBytes(),
        filename: imageFile.name,
      ),
    );
  }

  Future<String?> _uploadMultipart(http.MultipartFile file) async {
    if (uploadPreset.trim().isEmpty) {
      debugPrint(
        'Cloudinary upload preset is empty. Set SPENDLY_CLOUDINARY_UPLOAD_PRESET.',
      );
      return null;
    }
    if (cloudName.trim().isEmpty) {
      debugPrint(
        'Cloudinary cloud name is empty. Set SPENDLY_CLOUDINARY_CLOUD_NAME.',
      );
      return null;
    }

    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest("POST", url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(file);

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode < 200 ||
        streamedResponse.statusCode >= 300) {
      debugPrint(
        'Cloudinary upload failed (${streamedResponse.statusCode}). Body: $body',
      );
      return null;
    }

    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final secureUrl = data['secure_url'] as String?;
      if (secureUrl == null || secureUrl.isEmpty) {
        debugPrint(
          'Cloudinary upload succeeded but secure_url is missing. Body: $body',
        );
        return null;
      }
      return secureUrl;
    } catch (e) {
      debugPrint('Cloudinary response parse error: $e. Body: $body');
      return null;
    }
  }
}
