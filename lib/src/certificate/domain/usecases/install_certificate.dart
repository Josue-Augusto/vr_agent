import 'package:vr_agent/src/certificate/domain/repositories/certificate_installation_repository.dart';
import 'package:vr_agent/src/core/tools/platform_info.dart';

class InstallCertificate {
  final PlatformInfo platform;
  final CertificateInstallationRepository repository;
  final List<int> certificateBytes;

  const InstallCertificate({
    required this.platform,
    required this.repository,
    required this.certificateBytes,
  });

  Future<void> call() async {
    if (!platform.isWindows) {
      throw UnsupportedError('Comando válido somente para Windows.');
    }

    await repository.installCertificate(certificateBytes);
  }
}
