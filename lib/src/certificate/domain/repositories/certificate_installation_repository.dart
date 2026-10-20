abstract interface class CertificateInstallationRepository {
  Future<void> installCertificate(List<int> certificateBytes);
}
