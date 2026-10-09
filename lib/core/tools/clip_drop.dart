import 'dart:io';

class ClipDrop {
  static Future<void> copy(String text) async {
    if (Platform.isWindows) {
      final process = await Process.start('clip', []);
      process.stdin.write(text);
      await process.stdin.close();
      await process.exitCode;
      return;
    }

    if (Platform.isMacOS) {
      final process = await Process.start('pbcopy', []);
      process.stdin.write(text);
      await process.stdin.close();
      await process.exitCode;
      return;
    }

    if (Platform.isLinux) {
      final attempts = <List<String>>[
        ['xclip', '-selection', 'clipboard'],
        ['xsel', '--clipboard', '--input'],
      ];
      for (final cmd in attempts) {
        try {
          final process = await Process.start(cmd.first, cmd.sublist(1));
          process.stdin.write(text);
          await process.stdin.close();
          final code = await process.exitCode;
          if (code == 0) return;
        } catch (_) {}
      }
      throw StateError('Instale xclip ou xsel para copiar no Linux.');
    }

    throw UnsupportedError('Plataforma não suportada: ${Platform.operatingSystem}');
  }
}
