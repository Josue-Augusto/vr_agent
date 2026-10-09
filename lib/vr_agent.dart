import 'dart:developer' as developer;

import 'package:vr_agent/connection/data/repositories/connection_repository_impl.dart';
import 'package:vr_agent/connection/domain/repositories/connection_repository.dart';

class VRAgent {
  final ConnectionRepository _connectionRepository;

  VRAgent({ConnectionRepository? connectionRepository}) : _connectionRepository = connectionRepository ?? PostgreSQLConnectionImpl();

  Future<void> start() async {
    try {
      await _connectionRepository.init();
    } catch (error, stackTrace) {
      developer.log(
        'Initial PostgreSQL connection failed; automatic reconnection will continue.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> close() => _connectionRepository.close();
}
