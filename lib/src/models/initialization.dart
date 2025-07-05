import 'dart:async';

/// A type definition for a single step in the app's initialization process.
typedef InitializationStep = FutureOr<void> Function(AppFuseInitialization dependencies);

/// A mixin that defines the contract for providing app initialization steps.
///
/// Classes using this mixin must implement [initialisationSteps] to define their async setup logic.
mixin AppFuseInitialization {
  Map<String, InitializationStep> get initialisationSteps;
}

/// A default, empty implementation of [AppFuseInitialization]
class EmptyInitialization with AppFuseInitialization {
  @override
  Map<String, InitializationStep> get initialisationSteps => {};
}
