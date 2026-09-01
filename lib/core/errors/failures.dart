abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class LocationFailure extends Failure {
  const LocationFailure(super.message);
}

class CameraFailure extends Failure {
  const CameraFailure(super.message);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

class VerificationFailure extends Failure {
  const VerificationFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}
