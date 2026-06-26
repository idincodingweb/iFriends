import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Uploads images to Google Drive via the Apps Script bridge.
///
/// The Apps Script web app expects POST JSON:
/// { "folder": "profiles|posts|chats", "filename": "...", "mimeType": "image/jpeg", "base64": "..." }
/// and returns: { "url": "https://drive.google.com/uc?id=..." }.
class DriveService {
  DriveService._();
  static final DriveService instance = DriveService._();

  Future<String> uploadImage({
    required File file,
    required String folder,
  }) async {
    if (!AppConfig.isAppsScriptConfigured) {
      throw StateError(
        'Apps Script URL belum diset. Isi AppConfig.appsScriptUrl di lib/config/app_config.dart.',
      );
    }
    final bytes = await file.readAsBytes();
    final base64Str = base64Encode(bytes);
    final ext = file.path.split('.').last.toLowerCase();
    final mime = _mimeFor(ext);
    final filename =
        'ifriends_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final body = jsonEncode({
      'folder': folder,
      'filename': filename,
      'mimeType': mime,
      'base64': base64Str,
    });

    final res = await _postFollowingRedirects(
      Uri.parse(AppConfig.appsScriptUrl),
      body: body,
    );

    if (res.statusCode != 200) {
      throw HttpException(
        'Upload gagal (${res.statusCode}): ${res.body}',
      );
    }
    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw HttpException(
        'Respon Apps Script bukan JSON: ${res.body}',
      );
    }
    if (data['ok'] == false || data['error'] != null) {
      throw HttpException(
        'Apps Script error: ${data['error'] ?? data}',
      );
    }
    final url = (data['url'] ?? data['fileUrl']) as String?;
    if (url == null || url.isEmpty) {
      throw const HttpException('Apps Script tidak mengembalikan URL.');
    }
    return url;
  }

  /// Apps Script web apps respond to POST with a 302 redirect to
  /// `script.googleusercontent.com/...` where the actual JSON lives.
  /// The default `http.post` does not transparently follow cross-host
  /// POST→GET redirects, so we handle it manually.
  Future<http.Response> _postFollowingRedirects(
    Uri uri, {
    required String body,
    int maxRedirects = 5,
  }) async {
    final client = http.Client();
    try {
      var currentUri = uri;
      http.BaseRequest request = http.Request('POST', currentUri)
        ..headers['Content-Type'] = 'application/json'
        ..body = body
        ..followRedirects = false;

      for (var i = 0; i <= maxRedirects; i++) {
        final streamed = await client.send(request);
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 301 ||
            response.statusCode == 302 ||
            response.statusCode == 303 ||
            response.statusCode == 307 ||
            response.statusCode == 308) {
          final location = response.headers['location'];
          if (location == null) return response;
          currentUri = Uri.parse(location).isAbsolute
              ? Uri.parse(location)
              : currentUri.resolve(location);
          // After a redirect from Apps Script, switch to GET (no body).
          request = http.Request('GET', currentUri)..followRedirects = false;
          continue;
        }
        return response;
      }
      throw const HttpException('Terlalu banyak redirect dari Apps Script.');
    } finally {
      client.close();
    }
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
