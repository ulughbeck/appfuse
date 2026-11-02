/// Thrown when an initialization step fails. [error] is the original error.
class AppFuseInitException implements Exception {
  const AppFuseInitException(this.step, this.error);

  final String step;
  final Object error;

  @override
  String toString() => 'AppFuseInitException: step "$step" failed: $error';
}

/// Thrown when a config has no value for a key, a value of the wrong type, or no values at all.
class AppFuseConfigException implements Exception {
  const AppFuseConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppFuseConfigException: $message';
}
