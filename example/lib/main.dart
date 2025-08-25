// ignore_for_file: avoid_print

import 'package:appfuse/appfuse.dart';
import 'package:flutter/material.dart';

void main() {
  // Wrap your entire application with the AppFuseScope widget.
  // This widget handles all the initialization and provides state to your app.
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
      setup: Dependencies(),
      // A widget to show while dependencies are being initialized.
      placeholder: const SplashScreen(),
      // The main widget of your app, displayed after initialization is complete.
      app: const App(),
    ),
  );
}

/// Create a base configuration class for your app.
/// This extends one of the built-in config types, like `JsonAssetConfig`.
class AppConfig extends JsonAssetConfig {
  AppConfig({required super.path, required super.name, required super.color, super.showBanner});

  /// Define typed getters for your configuration values.
  /// This provides type safety and a single source of truth for config keys.
  String get appName => getString('APP_NAME');
}

/// Create concrete implementations for each environment.
class ProdConfig extends AppConfig {
  ProdConfig() : super(name: 'prod', path: 'config/prod.json', color: Colors.green);
}

class TestConfig extends AppConfig {
  TestConfig() : super(name: 'test', path: 'config/test.json', color: Colors.red);
}

// Mock classes for the example.
class A {}

class B {}

/// Define your app's dependencies and their initialization logic.
/// This class uses the `AppFuseInitialization` mixin to hook into the startup process.
class Dependencies with AppFuseSetup {
  Dependencies();

  /// A static helper method for easy access to your dependencies from anywhere
  /// in the widget tree.
  static Dependencies of(BuildContext context) => AppFuseScope.of(context, listen: false).setup as Dependencies;

  // Define late final variables for your services, repositories, etc.
  late final A dependencyA;
  late final B dependencyB;

  /// Define the asynchronous steps required to initialize your app.
  /// Each key is a descriptive name for the step, which is useful for logging.
  @override
  Map<String, InitializationStep> get steps => {
        'initialize dependency A': (config, self) async {
          // Perform async work like opening a database or initializing a service.
          await Future.delayed(const Duration(seconds: 1));
          dependencyA = A();
        },
        'initialize dependency B': (config, self) async {
          final c = config as AppConfig;
          c.appName;
          final d = self as Dependencies;
          d.dependencyA;

          await Future.delayed(const Duration(seconds: 1));
          dependencyB = B();
        },
      };
}

/// The root widget of your application.
class App extends StatelessWidget {
  // Define your environment configurations, app's themes and languages.

  /// AppFuse will automatically load the last used config or the first in the list.
  static final configs = [TestConfig(), ProdConfig()];

  /// The `themes` map defines the `ThemeData` for different brightness levels.
  /// AppFuse uses this to automatically switch between light and dark themes.
  /// You must provide at least a `Brightness.light` theme.
  static final themes = <Brightness, ThemeData>{Brightness.light: ThemeData.light()};

  /// The `appLanguages` map connects a `Locale` object to its human-readable name.
  /// This is used to build a language selector UI. The key is the `Locale`
  /// that Flutter uses, and the value is the string you would display to the user.
  static final supportedLanguages = <Locale, String>{const Locale('en'): 'English'};

  /// The `localizationsDelegates` list is a standard Flutter concept.
  /// It contains the delegates needed to load translated strings and format dates/numbers
  /// for the current locale. AppFuse passes this list directly to the `MaterialApp`.
  /// You typically get this list from packages like `flutter_localizations`.
  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[];

  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        // Use the context extensions to get state from AppFuse.
        // `watchSettings` rebuilds the widget when the value changes.
        // `readSettings` gets the value once without subscribing to changes.
        locale: context.currentLocale,
        supportedLocales: context.readSettings.supportedLocales,
        localizationsDelegates: context.readSettings.localizationsDelegates,
        themeMode: context.watchSettings.themeMode,
        theme: context.readSettings.lightTheme,
        darkTheme: context.readSettings.darkTheme,
        home: const HomeScreen(),
      );
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
    // Access any part of the AppFuse state.
    // Here, we read a custom setting that might have been saved.
    final onBoardingComplete = context.readSettings.getCustomSetting<bool>('onboarding');
    print('Onboarding complete: $onBoardingComplete'); // if not found, prints null

    // You can also access your initialized dependencies anywhere.
    final dependencyA = Dependencies.of(context).dependencyA;
    print('Accessed dependency: $dependencyA');
  }

  @override
  Widget build(BuildContext context) {
    // Get the current environment configuration and its values.
    // It's good practice to provide a default value in case the config is null.
    final appName = context.readSettings.getCurrentConfig<AppConfig>()?.appName ?? 'No Name';
    return Scaffold(
      appBar: AppBar(title: Text(appName)),
      body: const Center(child: Text('Home Screen')),
    );
  }
}

/// A simple placeholder widget shown during initialization.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}
