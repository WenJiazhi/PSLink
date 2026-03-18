import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'services/storage_service.dart';
import 'providers/device_provider.dart';
import 'providers/stream_provider.dart';
import 'screens/screens.dart';
import 'models/ps_device.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(storageService)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => PSStreamProvider(storageService)..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'PSLink',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AppNavigator(),
        routes: {
          Routes.home: (context) => const HomeScreen(),
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
      ),
    );
  }
}

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  bool _showSplash = true;

  void _onInitComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(onInitComplete: _onInitComplete);
    }
    return const HomeScreen();
  }
}
