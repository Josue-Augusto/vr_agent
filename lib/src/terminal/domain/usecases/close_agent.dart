import 'package:vr_agent/src/connection/domain/repositories/connection_repository.dart';

class CloseAgent {
  final ConnectionRepository _connectionRepository;

  const CloseAgent(this._connectionRepository);

  Future<void> call() => _connectionRepository.close();
}
