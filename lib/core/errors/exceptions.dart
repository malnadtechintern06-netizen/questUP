class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => 'AppException: $message';
}

class LocationException extends AppException {
  const LocationException(super.message);
}

class CameraException extends AppException {
  const CameraException(super.message);
}

class StorageException extends AppException {
  const StorageException(super.message);
}

class VerificationException extends AppException {
  const VerificationException(super.message);
}
