import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Resumable upload to Supabase Storage using the TUS 1.0.0 protocol.
///
/// Implemented directly over Dio (no extra dependency) so it stays compatible
/// with the project's pinned `storage_client` version. Supports resume after a
/// network interruption via the TUS `HEAD`/`Upload-Offset` mechanism, which is
/// essential on unstable mobile networks.
///
/// All heavy video compression/transcoding happens server-side (Kamatera); this
/// service only transfers the original file reliably to the bucket/path that was
/// allocated by `app_videoasset_create_upload_intent`.
class TusUploadService {
  TusUploadService._();

  /// Supabase requires the TUS chunk size to be exactly 6 MB.
  static const int chunkSize = 6 * 1024 * 1024;
  static const String _tusVersion = '1.0.0';
  static const int _maxRetriesPerChunk = 5;

  static SupabaseClient get _client => Supabase.instance.client;

  static String get _endpoint =>
      '${SupabaseConfig.url}/storage/v1/upload/resumable';

  /// Uploads [file] to [bucket]/[objectPath] resumably.
  ///
  /// Calls [onProgress] with a 0.0–1.0 fraction. Returns the public URL on
  /// success, or `null` on failure (caller decides how to surface the error).
  static Future<String?> uploadFile({
    required File file,
    required String bucket,
    required String objectPath,
    String contentType = 'video/mp4',
    ValueChanged<double>? onProgress,
    CancelToken? cancelToken,
  }) async {
    final String? token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('[TUS] Pas de session/token — upload impossible');
      return null;
    }

    final int fileSize = await file.length();
    if (fileSize <= 0) {
      debugPrint('[TUS] Fichier vide — upload annulé');
      return null;
    }

    final Dio dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(seconds: 60),
    ));

    // 1) Create the resumable upload (TUS "creation" extension).
    final String? location = await _createUpload(
      dio: dio,
      token: token,
      bucket: bucket,
      objectPath: objectPath,
      contentType: contentType,
      fileSize: fileSize,
      cancelToken: cancelToken,
    );
    if (location == null) return null;
    final String uploadUrl = _resolveLocation(location);

    // 2) Upload chunks sequentially, resuming on transient failures.
    final RandomAccessFile raf = await file.open();
    try {
      int offset = 0;
      int chunkAttempt = 0;
      while (offset < fileSize) {
        final int end =
            (offset + chunkSize < fileSize) ? offset + chunkSize : fileSize;
        await raf.setPosition(offset);
        final Uint8List chunk = await raf.read(end - offset);

        try {
          final Response<dynamic> resp = await dio.patchUri<dynamic>(
            Uri.parse(uploadUrl),
            data: Stream<List<int>>.fromIterable(<List<int>>[chunk]),
            options: Options(
              headers: <String, dynamic>{
                'Tus-Resumable': _tusVersion,
                'Upload-Offset': offset.toString(),
                'Content-Type': 'application/offset+octet-stream',
                'Authorization': 'Bearer $token',
                'content-length': chunk.length,
              },
              validateStatus: (int? s) => s != null && s < 500,
            ),
            cancelToken: cancelToken,
          );

          final int status = resp.statusCode ?? 0;
          if (status == 204 || status == 200) {
            final int? newOffset =
                int.tryParse(resp.headers.value('upload-offset') ?? '');
            offset = newOffset ?? end;
            chunkAttempt = 0;
            onProgress?.call(offset / fileSize);
          } else if (status == 409 || status == 460) {
            // Offset conflict — re-sync from the server and retry.
            final int? serverOffset =
                await _headOffset(dio, uploadUrl, token, cancelToken);
            if (serverOffset == null) return null;
            offset = serverOffset;
            onProgress?.call(offset / fileSize);
          } else {
            debugPrint('[TUS] PATCH statut inattendu: $status');
            return null;
          }
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) {
            debugPrint('[TUS] Upload annulé');
            return null;
          }
          chunkAttempt++;
          if (chunkAttempt >= _maxRetriesPerChunk) {
            debugPrint('[TUS] Échec chunk après $chunkAttempt essais: ${e.message}');
            return null;
          }
          // Exponential-ish backoff, then re-sync the offset before retrying.
          await Future<void>.delayed(Duration(seconds: chunkAttempt * 2));
          final int? serverOffset =
              await _headOffset(dio, uploadUrl, token, cancelToken);
          if (serverOffset != null) offset = serverOffset;
        }
      }
    } finally {
      await raf.close();
    }

    onProgress?.call(1.0);
    return _client.storage.from(bucket).getPublicUrl(objectPath);
  }

  static Future<String?> _createUpload({
    required Dio dio,
    required String token,
    required String bucket,
    required String objectPath,
    required String contentType,
    required int fileSize,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<dynamic> resp = await dio.postUri<dynamic>(
        Uri.parse(_endpoint),
        options: Options(
          headers: <String, dynamic>{
            'Tus-Resumable': _tusVersion,
            'Upload-Length': fileSize.toString(),
            'Upload-Metadata': _encodeMetadata(<String, String>{
              'bucketName': bucket,
              'objectName': objectPath,
              'contentType': contentType,
              'cacheControl': '3600',
            }),
            'Authorization': 'Bearer $token',
            'x-upsert': 'true',
          },
          validateStatus: (int? s) => s != null && s < 500,
        ),
        cancelToken: cancelToken,
      );
      if (resp.statusCode == 201) {
        final String? location = resp.headers.value('location');
        if (location == null || location.isEmpty) {
          debugPrint('[TUS] create: en-tête Location manquant');
        }
        return location;
      }
      debugPrint('[TUS] create échec: ${resp.statusCode} ${resp.data}');
      return null;
    } on DioException catch (e) {
      debugPrint('[TUS] create erreur: ${e.message}');
      return null;
    }
  }

  static Future<int?> _headOffset(
    Dio dio,
    String uploadUrl,
    String token,
    CancelToken? cancelToken,
  ) async {
    try {
      final Response<dynamic> resp = await dio.headUri<dynamic>(
        Uri.parse(uploadUrl),
        options: Options(
          headers: <String, dynamic>{
            'Tus-Resumable': _tusVersion,
            'Authorization': 'Bearer $token',
          },
          validateStatus: (int? s) => s != null && s < 500,
        ),
        cancelToken: cancelToken,
      );
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        return int.tryParse(resp.headers.value('upload-offset') ?? '');
      }
      return null;
    } catch (e) {
      debugPrint('[TUS] HEAD erreur: $e');
      return null;
    }
  }

  static String _resolveLocation(String location) {
    if (location.startsWith('http://') || location.startsWith('https://')) {
      return location;
    }
    final Uri base = Uri.parse(_endpoint);
    final String authority = base.hasPort ? '${base.host}:${base.port}' : base.host;
    if (location.startsWith('/')) {
      return '${base.scheme}://$authority$location';
    }
    return '$_endpoint/$location';
  }

  static String _encodeMetadata(Map<String, String> meta) {
    return meta.entries
        .map((MapEntry<String, String> e) =>
            '${e.key} ${base64.encode(utf8.encode(e.value))}')
        .join(',');
  }
}
