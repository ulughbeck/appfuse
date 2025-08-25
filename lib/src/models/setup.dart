import 'dart:async';

import 'package:appfuse/appfuse.dart';

/// A type definition for a single step in the app's initialization process.
typedef InitializationStep = Future<void> Function(BaseConfig config, AppFuseSetup self);

/// A mixin that defines the contract for providing app initialization steps.
///
/// Classes using this mixin must implement [steps] to define their async setup logic.
mixin AppFuseSetup {
  Map<String, InitializationStep> get steps;
}

/// A default, empty implementation of [AppFuseSetup]
class EmptyInitialization with AppFuseSetup {
  @override
  Map<String, InitializationStep> get steps => {};
}
