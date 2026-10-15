import 'package:vr_agent/src/service/domain/repositories/system_service_installation_repository.dart';

class InstallSystemService {
  final SystemServiceInstallationRepository repository;

  const InstallSystemService(this.repository);

  Future<void> call() => repository.install();
}
