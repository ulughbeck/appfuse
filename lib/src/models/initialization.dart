import 'dart:async';

import 'state.dart';

/// A type definition for a single step in the app's initialization process.
typedef InitializationStep = Future<void> Function(AppFuseState state);

/// A mixin that defines the contract for providing app initialization steps.
///
/// Classes using this mixin must implement [steps] to define their async setup logic.
mixin AppFuseInitialization {
  Map<String, InitializationStep> get steps;

  /// Releases what the [steps] created, for example clients and open connections.
  ///
  /// AppFuse calls it before a config switch or a retry creates a new instance, and when the controller is disposed.
  FutureOr<void> dispose() {}
}
