import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';

class StartAgent {
  final ConnectionRepository _connectionRepository;

  const StartAgent(this._connectionRepository);

  Future<void> call() => _connectionRepository.init();
}
