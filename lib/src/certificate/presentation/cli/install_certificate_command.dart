import 'dart:io';

import 'package:vr_agent/src/certificate/domain/usecases/install_certificate.dart';

class InstallCertificateCommand {
  final InstallCertificate _installCertificate;

  const InstallCertificateCommand(this._installCertificate);

  Future<int> call(List<String> arguments) async {
    if (arguments.isNotEmpty) {
      stderr.writeln('Uso: vr_agent -a -install -certificate');
      return 64;
    }

    try {
      await _installCertificate();
      stdout.writeln('Certificado instalado no repositório de certificados raiz do Windows.');
      return 0;
    } on UnsupportedError catch (error) {
      stderr.writeln(error.message);
      return 69;
    } catch (error) {
      stderr.writeln('Falha ao instalar o certificado: $error');
      return 1;
    }
  }
}
