import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'services/storage_service.dart';
import 'providers/device_provider.dart';
import 'providers/stream_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/streaming_screen.dart';
import 'package:pslink/screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'core/constants.dart';
import 'models/ps_device.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure supported orientations.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Configure system UI chrome.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(AppColors.backgroundColor),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize local storage.
  final storageService = StorageService();
  await storageService.initialize();

  runApp(PSLinkApp(storageService: storageService));
}

class PSLinkApp extends StatelessWidget {
  final StorageService storageService;

  const PSLinkApp({
    super.key,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Storage service.
        Provider<StorageService>.value(value: storageService),

        // Device state.
        ChangeNotifierProvider(
          create: (context) => DeviceProvider(storageService)..initialize(),
        ),

        // Streaming state.
        ChangeNotifierProvider(
          create: (context) => PSStreamProvider(storageService)..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'PSLink',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: Routes.splash,
        routes: {
          Routes.splash: (context) => SplashScreen(
                onInitComplete: () {
                  Navigator.of(context).pushReplacementNamed(Routes.home);
                },
              ),
          Routes.home: (context) => const HomeScreen(),
          Routes.streaming: (context) => const StreamingScreen(),
          Routes.settings: (context) => const SettingsScreen(),
          Routes.about: (context) => const AboutScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == Routes.registration) {
            final device = settings.arguments;
            if (device is PSDevice) {
              return MaterialPageRoute(
                builder: (context) => RegistrationScreen(device: device),
              );
            }
          }
          return null;
        },
        // Fallback for unknown routes.
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          );
        },
      ),
    );
  }
}
