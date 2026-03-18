import 'package:flutter/material.dart';
import '../core/constants.dart';

/// 启动页面
/// 显示 PSLink logo 和加载动画，初始化服务后跳转到主页
class SplashScreen extends StatefulWidget {
  final VoidCallback onInitComplete;

  const SplashScreen({
    super.key,
    required this.onInitComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 初始化动画
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // 启动动画
    _animationController.forward();

    // 模拟初始化过程
    _initialize();
  }

  Future<void> _initialize() async {
    // 等待动画完成
    await Future.delayed(const Duration(milliseconds: 2000));

    // 调用初始化完成回调
    if (mounted) {
      widget.onInitComplete();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(AppColors.backgroundColor),
              Color(AppColors.primaryColor).withOpacity(0.3),
              Color(AppColors.backgroundColor),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // PSLink Logo
                _buildLogo(),
                const SizedBox(height: 32),

                // App 名称
                Text(
                  'PSLink',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Color(AppColors.textPrimary),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                ),
                const SizedBox(height: 8),

                // 副标题
                Text(
                  'PlayStation Remote Play',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Color(AppColors.textSecondary),
                        letterSpacing: 1,
                      ),
                ),
                const SizedBox(height: 48),

                // 加载指示器
                _buildLoadingIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(AppColors.primaryColor),
            Color(AppColors.accentColor),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Color(AppColors.accentColor).withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.sports_esports,
          size: 64,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation<Color>(
          Color(AppColors.accentColor),
        ),
      ),
    );
  }
}
