import 'package:vr_agent/src/core/tools/platform_info.dart';

abstract interface class PowerToolsBinaryInstaller {
  Future<void> install({required String repositoryUrl, required String executablePath, required PlatformInfo platform});
}
