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
        // 设备状态管理
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(storageService),
        ),
        // 串流状态管理
        ChangeNotifierProvider(
          create: (_) => StreamProvider(storageService),
        ),
      ],
      child: MaterialApp(
        title: 'PSLink',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AppNavigator(),
        routes: {
          Routes.home: (context) => const HomeScreen(),
          Routes.registration: (context) {
            final device = ModalRoute.of(context)?.settings.arguments as PSDevice?;
            if (device == null) {
              return const HomeScreen();
            }
            return RegistrationScreen(device: device);
          },
          // 其他路由可以在这里添加
          // Routes.streaming: (context) => const StreamingScreen(),
          // Routes.settings: (context) => const SettingsScreen(),
        },
      ),
    );
  }
}

/// 应用导航器
/// 处理启动页到主页的过渡
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
