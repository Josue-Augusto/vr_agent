import 'package:postgres/postgres.dart';
import 'package:vr_agent/connection/domain/entitie/connection_entity.dart';

abstract interface class ConnectionRepository {
  Future<void> init({String? user, String? password});
  Future<Connection> getConnection({String? user, String? password});
  Future<Result> execute(Object query, {Object? parameters});
  Future<ConnectionEntity> getConfig();
  bool isVerifiedFor(ConnectionEntity config);
  Future<void> reconnect({String? user, String? password});
  Future<void> close();
}
