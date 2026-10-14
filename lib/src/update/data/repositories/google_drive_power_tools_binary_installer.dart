import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:vr_agent/src/core/tools/platform_info.dart';
import 'package:vr_agent/src/update/domain/repositories/power_tools_binary_installer.dart';

class GoogleDrivePowerToolsBinaryInstaller implements PowerToolsBinaryInstaller {
  final Dio _dio;
  final Future<String> Function(String executablePath) _versionReader;

  GoogleDrivePowerToolsBinaryInstaller({
    Dio? dio,
    Future<String> Function(String executablePath)? versionReader,
  }) : _dio = dio ?? Dio(),
       _versionReader = versionReader ?? _readBinaryVersion;

  @override
  Future<bool> isInstalled({required String executablePath}) => File(executablePath).exists();

  @override
  Future<void> install({
    required String repositoryUrl,
    required String executablePath,
    required PlatformInfo platform,
    String? expectedVersion,
  }) async {
    final downloadUrl = _downloadUrl(repositoryUrl);
    final target = File(executablePath);
    await target.parent.create(recursive: true);
    final suffix = platform.isWindows ? '.exe' : '';
    final temporary = File(
      p.join(
        target.parent.path,
        '.${p.basename(target.path)}.${DateTime.now().microsecondsSinceEpoch}.download$suffix',
      ),
    );
    final backup = File(
      p.join(
        target.parent.path,
        '.${p.basename(target.path)}.${DateTime.now().microsecondsSinceEpoch}.backup',
      ),
    );
    var targetMovedToBackup = false;

    try {
      var response = await _download(downloadUrl, temporary.path);
      if (await _isHtmlResponse(response, temporary)) {
        final confirmation = await _confirmationRequest(
          response: response,
          htmlFile: temporary,
          initialUrl: downloadUrl,
        );
        if (confirmation == null) {
          throw const FormatException(
            'O Google Drive não forneceu um download direto nem uma '
            'confirmação automática. Verifique se o arquivo está compartilhado '
            'com acesso público por link.',
          );
        }
        response = await _download(
          confirmation.url,
          temporary.path,
          headers: confirmation.headers,
        );
      }
      if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! >= 300 || !await temporary.exists() || await temporary.length() == 0) {
        throw HttpException(
          'O download do PowerTools retornou um arquivo vazio ou inválido.',
          uri: Uri.parse(downloadUrl),
        );
      }
      if (await _isHtmlResponse(response, temporary)) {
        throw const FormatException(
          'O Google Drive ainda retornou uma página HTML após a confirmação. '
          'Verifique se o link permite baixar o arquivo sem autenticação.',
        );
      }

      if (platform.isLinux) {
        final chmod = await Process.run('chmod', ['u+x', temporary.path]);
        if (chmod.exitCode != 0) {
          throw ProcessException(
            'chmod',
            ['u+x', temporary.path],
            '${chmod.stderr}',
            chmod.exitCode,
          );
        }
      }

      if (expectedVersion != null) {
        await _validateDownloadedBinary(
          temporary.path,
          expectedVersion: expectedVersion,
        );
      }

      if (await target.exists()) {
        await target.rename(backup.path);
        targetMovedToBackup = true;
      }
      try {
        await temporary.rename(target.path);
      } catch (error, stackTrace) {
        if (targetMovedToBackup) {
          try {
            await backup.rename(target.path);
            targetMovedToBackup = false;
          } catch (restoreError, restoreStackTrace) {
            Error.throwWithStackTrace(
              StateError(
                'Não foi possível instalar o novo binário ($error) nem '
                'restaurar o PowerTools anterior ($restoreError).',
              ),
              restoreStackTrace,
            );
          }
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      if (targetMovedToBackup) {
        try {
          await backup.delete();
          targetMovedToBackup = false;
        } catch (error, stackTrace) {
          developer.log(
            'O novo PowerTools foi instalado, mas o backup anterior não pôde ser removido.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _validateDownloadedBinary(
    String executablePath, {
    required String expectedVersion,
  }) async {
    final output = await _versionReader(executablePath);
    final matches = RegExp(
      r'(?<![A-Za-z0-9.])v?(\d+(?:\.\d+)+)(?![A-Za-z0-9.])',
    ).allMatches(output);
    if (matches.isEmpty) {
      throw FormatException(
        'Não foi possível identificar a versão do PowerTools baixado: '
        '${output.trim()}',
      );
    }
    final downloadedVersion = matches.last.group(1)!;
    if (_compareVersions(downloadedVersion, expectedVersion) < 0) {
      throw StateError(
        'O arquivo no link de download contém PowerTools $downloadedVersion, '
        'mas o banco espera $expectedVersion. O executável instalado não foi alterado. '
        'Atualize o link do arquivo da versão $expectedVersion.',
      );
    }
  }

  static Future<String> _readBinaryVersion(String executablePath) async {
    final result = await Process.run(
      executablePath,
      ['-version'],
      workingDirectory: File(executablePath).parent.path,
      runInShell: false,
    ).timeout(const Duration(seconds: 30));
    if (result.exitCode != 0) {
      throw StateError(
        'O PowerTools baixado não conseguiu informar sua versão. '
        'Código ${result.exitCode}: ${result.stderr}',
      );
    }
    return '${result.stdout}\n${result.stderr}';
  }

  int _compareVersions(String left, String right) {
    final leftParts = left.split('.').map(int.parse).toList(growable: false);
    final rightParts = right.split('.').map(int.parse).toList(growable: false);
    final length = leftParts.length > rightParts.length ? leftParts.length : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftPart = index < leftParts.length ? leftParts[index] : 0;
      final rightPart = index < rightParts.length ? rightParts[index] : 0;
      if (leftPart != rightPart) return leftPart.compareTo(rightPart);
    }
    return 0;
  }

  Future<Response<dynamic>> _download(
    String url,
    String outputPath, {
    Map<String, Object>? headers,
  }) => _dio.download(
    url,
    outputPath,
    options: Options(
      followRedirects: true,
      headers: headers,
      validateStatus: (status) => status != null && status < 400,
    ),
  );

  Future<bool> _isHtmlResponse(
    Response<dynamic> response,
    File downloadedFile,
  ) async {
    final contentType = response.headers.value(Headers.contentTypeHeader);
    if (contentType?.toLowerCase().contains('text/html') ?? false) {
      return true;
    }
    if (!await downloadedFile.exists()) return false;
    final file = await downloadedFile.open();
    try {
      final leadingBytes = await file.read(512);
      final leadingText = utf8.decode(leadingBytes, allowMalformed: true).trimLeft().toLowerCase();
      return leadingText.startsWith('<!doctype html') || leadingText.startsWith('<html') || leadingText.startsWith('<head') || leadingText.startsWith('<body');
    } finally {
      await file.close();
    }
  }

  Future<_GoogleDriveConfirmation?> _confirmationRequest({
    required Response<dynamic> response,
    required File htmlFile,
    required String initialUrl,
  }) async {
    final html = await htmlFile.readAsString();
    final cookies = _cookiesFrom(response.headers);
    final form = _confirmationForm(html, response.realUri);
    if (form != null) {
      return _GoogleDriveConfirmation(
        url: form.url,
        headers: cookies.isEmpty ? const {} : {'Cookie': cookies},
      );
    }

    final token = _confirmationToken(html) ?? _downloadWarningCookie(cookies);
    if (token == null) return null;
    final uri = Uri.parse(initialUrl);
    return _GoogleDriveConfirmation(
      url: uri
          .replace(
            queryParameters: {...uri.queryParameters, 'confirm': token},
          )
          .toString(),
      headers: cookies.isEmpty ? const {} : {'Cookie': cookies},
    );
  }

  _GoogleDriveConfirmation? _confirmationForm(String html, Uri responseUri) {
    final forms = RegExp(
      r'<form\b([^>]*)>(.*?)</form\s*>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);
    for (final form in forms) {
      final formAttributes = _htmlAttributes(form.group(1)!);
      final action = formAttributes['action'];
      if (action == null) continue;

      final query = <String, String>{};
      for (final input in RegExp(
        r'<input\b([^>]*)>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(form.group(2)!)) {
        final attributes = _htmlAttributes(input.group(1)!);
        if (attributes['type']?.toLowerCase() != 'hidden') continue;
        final name = attributes['name'];
        final value = attributes['value'];
        if (name != null && value != null) query[name] = value;
      }
      if (!query.containsKey('confirm') && !query.containsKey('uuid') && !query.containsKey('export')) {
        continue;
      }

      final actionUri = responseUri.resolve(_decodeHtml(action));
      if (actionUri.scheme != 'https' || !_isGoogleDriveHost(actionUri.host)) {
        throw const FormatException(
          'O formulário de confirmação do Google Drive apontou para um '
          'endereço inválido.',
        );
      }
      return _GoogleDriveConfirmation(
        url: actionUri.replace(queryParameters: {...actionUri.queryParameters, ...query}).toString(),
        headers: const {},
      );
    }
    return null;
  }

  Map<String, String> _htmlAttributes(String source) {
    final attributes = <String, String>{};
    final pattern = RegExp(
      r'''([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(source)) {
      final value = match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      attributes[match.group(1)!.toLowerCase()] = _decodeHtml(value);
    }
    return attributes;
  }

  String _decodeHtml(String value) => value.replaceAll('&amp;', '&').replaceAll('&#x3D;', '=').replaceAll('&#61;', '=');

  String? _confirmationToken(String html) {
    final token = RegExp(
      r'''(?:[?&]confirm=|name=["']confirm["']\s+value=["'])([^&"'<> \s]+)''',
      caseSensitive: false,
    ).firstMatch(html)?.group(1);
    return token == null ? null : _decodeHtml(token);
  }

  String _cookiesFrom(Headers headers) => (headers['set-cookie'] ?? const []).map((cookie) => cookie.split(';').first.trim()).where((cookie) => cookie.contains('=')).join('; ');

  String? _downloadWarningCookie(String cookies) {
    final match = RegExp(
      r'(download_warning[^=]*)=([^;]+)',
      caseSensitive: false,
    ).firstMatch(cookies);
    return match?.group(2);
  }

  String _downloadUrl(String repositoryUrl) {
    final uri = Uri.tryParse(repositoryUrl);
    if (uri == null || uri.scheme != 'https' || !_isGoogleDriveHost(uri.host) || uri.port != 443 || uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'O campo repository deve conter um link HTTPS do Google Drive.',
      );
    }

    final pathMatch = RegExp(r'/file/d/([^/]+)').firstMatch(uri.path);
    final fileId = pathMatch?.group(1) ?? uri.queryParameters['id'];
    if (fileId == null || fileId.isEmpty) {
      throw FormatException('Não foi possível identificar o arquivo em "$repositoryUrl".');
    }
    return Uri.https(
      'drive.usercontent.google.com',
      '/download',
      {'export': 'download', 'id': fileId},
    ).toString();
  }

  bool _isGoogleDriveHost(String host) {
    final normalizedHost = host.toLowerCase();
    return normalizedHost == 'drive.google.com' || normalizedHost == 'drive.usercontent.google.com';
  }
}

class _GoogleDriveConfirmation {
  final String url;
  final Map<String, Object> headers;

  const _GoogleDriveConfirmation({required this.url, required this.headers});
}
