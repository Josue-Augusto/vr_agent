import 'dart:io';

import 'package:vr_agent/src/certificate/domain/repositories/certificate_installation_repository.dart';

class WindowsCertificateInstallationRepository
    implements CertificateInstallationRepository {
  const WindowsCertificateInstallationRepository();

  @override
  Future<void> installCertificate(List<int> certificateBytes) async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'vr-agent-certificate-',
    );
    try {
      final certificateFile = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}Certificado.cer',
      );
      await certificateFile.writeAsBytes(certificateBytes, flush: true);

      const arguments = ['-addstore', '-f', 'Root'];
      final result = await Process.run(
        'certutil',
        [...arguments, certificateFile.path],
      );
      if (result.exitCode != 0) {
        throw ProcessException(
          'certutil',
          [...arguments, certificateFile.path],
          '${result.stdout}${result.stderr}',
          result.exitCode,
        );
      }
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  }
}
