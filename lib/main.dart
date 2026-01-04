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
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 设置全屏和方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(AppColors.backgroundColor),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // 初始化存储服务
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
        // 存储服务
        Provider<StorageService>.value(value: storageService),

        // 设备管理
        ChangeNotifierProvider(
          create: (context) => DeviceProvider(storageService)..initialize(),
        ),

        // 串流管理
        ChangeNotifierProvider(
          create: (context) => StreamProvider(storageService)..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'PSLink',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: Routes.splash,
        routes: {
          Routes.splash: (context) => const SplashScreen(),
          Routes.home: (context) => const HomeScreen(),
          Routes.registration: (context) => const RegistrationScreen(),
          Routes.streaming: (context) => const StreamingScreen(),
          Routes.settings: (context) => const SettingsScreen(),
          Routes.about: (context) => const AboutScreen(),
        },
        // 路由未找到处理
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          );
        },
      ),
    );
  }
}
