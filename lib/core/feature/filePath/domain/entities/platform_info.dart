import 'dart:io';

enum SupportedPlatform { windows, linux }

class PlatformInfo {
  final SupportedPlatform platform;

  factory PlatformInfo.fromOperatingSystem(String operatingSystem) {
    final platform = switch (operatingSystem) {
      'windows' => SupportedPlatform.windows,
      'linux' => SupportedPlatform.linux,
      _ => throw UnsupportedError(
        'Plataforma não suportada: $operatingSystem. '
        'As plataformas suportadas são Windows e Linux.',
      ),
    };
    return PlatformInfo._(platform);
  }

  const PlatformInfo._(this.platform);

  static final PlatformInfo current = PlatformInfo.fromOperatingSystem(
    Platform.operatingSystem,
  );

  bool get isWindows => platform == SupportedPlatform.windows;
  bool get isLinux => platform == SupportedPlatform.linux;

  String get operatingSystem => switch (platform) {
    SupportedPlatform.windows => 'windows',
    SupportedPlatform.linux => 'linux',
  };

  String get displayName => switch (platform) {
    SupportedPlatform.windows => 'Windows',
    SupportedPlatform.linux => 'Linux',
  };

  String get pathSeparator => isWindows ? r'\' : '/';
}
