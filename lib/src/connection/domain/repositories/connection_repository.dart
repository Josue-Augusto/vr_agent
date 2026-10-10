import 'package:vr_agent/src/connection/domain/entitie/connection_config.dart';

abstract interface class ConnectionRepository {
  Future<void> init({String? user, String? password});
  Future<ConnectionConfig> getConfig();
  bool isVerifiedFor(ConnectionConfig config);
  Future<void> reconnect({String? user, String? password});
  Future<void> close();
}
