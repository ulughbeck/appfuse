// ignore_for_file: avoid_print

import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

void main() {
  // AppFuseScope runs the initialization and provides the state to the app.
  runApp(
    AppFuseScope(
      // The list of environment configurations your app can use.
      configs: App.configs,
      // A map of themes for light/dark mode.
      themes: App.themes,
      // A map of supported languages for localization.
      supportedLanguages: App.supportedLanguages,
      // Your app's localization delegates.
      localizationsDelegates: App.localizationsDelegates,
      // The class that defines your app's asynchronous initialization steps.
      init: Dependencies.new,
      // Shown during config switches and retries. The native splash stays
      // until the startup ends. Set `keepNativeSplash: false` to show it at startup.
      placeholder: const SplashScreen(),
      // Shown when a step fails or the initialization times out.
      // `retry` runs the startup again with a new `Dependencies`.
      errorBuilder: (error, stackTrace, retry) =>
          ErrorScreen(error: error, onRetry: retry),
      app: const App(),
    ),
  );
}

/// The config keys of the app. Each key has the type of its value.
abstract final class Keys {
  static const appName = ConfigKey<String>('APP_NAME');
}

/// A base configuration class for the app's environments.
class AppConfig extends JsonAssetConfig {
  AppConfig({
    required super.path,
    required super.name,
    required super.color,
    super.showBanner,
  });

  /// Typed getters keep the config keys in one place.
  String get appName => read(Keys.appName);
}

/// Create concrete implementations for each environment.
class ProdConfig extends AppConfig {
  ProdConfig()
    : super(
        name: 'prod',
        path: 'config/prod.json',
        color: Colors.green,
        showBanner: true,
      );
}

class TestConfig extends AppConfig {
  TestConfig()
    : super(
        name: 'test',
        path: 'config/test.json',
        color: Colors.red,
        showBanner: true,
      );
}

// Mock classes for the example.
class A {}

class B {}

/// The app's dependencies and the steps that create them.
class Dependencies with AppFuseInitialization {
  /// Reads the dependencies anywhere below [AppFuseScope].
  static Dependencies of(BuildContext context) =>
      AppFuseScope.initOf<Dependencies>(context);

  late final A dependencyA;
  late final B dependencyB;

  /// Each key names the step in progress messages and errors.
  @override
  Map<String, InitializationStep> get steps => {
    'initialize dependency A': (state) async {
      // Perform async work like opening a database or initializing a service.
      await Future<void>.delayed(const Duration(seconds: 1));
      dependencyA = A();
    },
    'initialize dependency B': (state) async {
      // The active config is ready before the app's steps run.
      print('Config app name: ${state.getCurrentConfig<AppConfig>()?.appName}');
      // Earlier steps are done, so their dependencies are ready.
      print('Dependency A: $dependencyA');
      await Future<void>.delayed(const Duration(seconds: 1));
      dependencyB = B();
    },
  };
}

/// The root widget of your application.
class App extends StatelessWidget {
  const App({super.key});

  /// AppFuse loads the last used config or the first in the list.
  static final configs = [TestConfig(), ProdConfig()];

  /// The light theme is optional. Without a dark theme, the theme picker shows only light.
  static final themes = <Brightness, ThemeData>{
    Brightness.light: ThemeData.light(),
    Brightness.dark: ThemeData.dark(),
  };

  /// Connects each `Locale` to the name that the language picker shows.
  static final supportedLanguages = <Locale, String>{
    const Locale('en'): 'English',
  };

  /// AppFuse keeps this list in its state. It does not pass it to `MaterialApp`, so the app does that.
  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[];

  @override
  Widget build(BuildContext context) {
    // `currentLocale` and `currentThemeMode` rebuild only when their value changes.
    // `AppFuseScope.read` reads the state once without a subscription.
    final state = AppFuseScope.read(context);
    return MaterialApp(
      locale: context.currentLocale,
      supportedLocales: state.supportedLocales,
      localizationsDelegates: state.localizationsDelegates,
      themeMode: context.currentThemeMode,
      theme: state.lightTheme,
      darkTheme: state.darkTheme,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // A custom setting that was not saved reads as null.
    final onboardingComplete = AppFuseScope.read(
      context,
    ).getCustomSetting<bool>('onboarding');
    print('Onboarding complete: $onboardingComplete');

    final dependencyA = Dependencies.of(context).dependencyA;
    print('Accessed dependency: $dependencyA');
  }

  @override
  Widget build(BuildContext context) {
    final appName =
        AppFuseScope.read(context).getCurrentConfig<AppConfig>()?.appName ??
        'No Name';
    return Scaffold(
      appBar: AppBar(
        title: Text(appName),
        actions: [
          const LocalizationIconButton(),
          const ThemeIconButton(),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Debug menu',
            onPressed: () => showAppFuseMenu(context),
          ),
        ],
      ),
      body: const Center(child: Text('Home Screen')),
    );
  }
}

/// A simple placeholder widget shown during initialization.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: Text('Loading'));
}

/// Shows the startup error and a button that runs the startup again.
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Startup failed: $error', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
