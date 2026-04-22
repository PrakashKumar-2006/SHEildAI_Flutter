abstract class Failure {
  const Failure();

  String get message;
}

class ServerFailure extends Failure {
  @override
  final String message;

  const ServerFailure(this.message);
}

class NetworkFailure extends Failure {
  @override
  final String message;

  const NetworkFailure(this.message);
}

class PermissionFailure extends Failure {
  @override
  final String message;

  const PermissionFailure(this.message);
}

class StorageFailure extends Failure {
  @override
  final String message;

  const StorageFailure(this.message);
}

class LocationFailure extends Failure {
  @override
  final String message;

  const LocationFailure(this.message);
}
