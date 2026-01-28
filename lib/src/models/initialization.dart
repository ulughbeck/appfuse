import 'dart:async';

import 'package:appfuse/appfuse.dart';

/// A type definition for a single step in the app's initialization process.
typedef InitializationStep = Future<void> Function(AppFuseState state);

/// A mixin that defines the contract for providing app initialization steps.
///
/// Classes using this mixin must implement [steps] to define their async setup logic.
mixin AppFuseInitialization {
  Map<String, InitializationStep> get steps;
}

/// A default, empty implementation of [AppFuseInitialization]
class EmptyInitialization with AppFuseInitialization {
  @override
  Map<String, InitializationStep> get steps => {};
}
