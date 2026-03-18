import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../core/constants.dart';
import '../providers/device_provider.dart';
import '../providers/stream_provider.dart';
import '../widgets/virtual_controller.dart';
import '../services/streaming_service.dart';

/// 串流页面
class StreamingScreen extends StatefulWidget {
  const StreamingScreen({super.key});

  @override
  State<StreamingScreen> createState() => _StreamingScreenState();
}

class _StreamingScreenState extends State<StreamingScreen> {
  bool _isFullscreen = false;
  bool _showController = false;
  int _tapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _enableFullscreen();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final device = context.read<DeviceProvider>().selectedDevice;
      final streamProvider = context.read<PSStreamProvider>();
      if (device != null && !streamProvider.isConnected && !streamProvider.isConnecting) {
        await streamProvider.startStreaming(device);
      }
    });
  }

  @override
  void dispose() {
    _disableFullscreen();
    WakelockPlus.disable();
    super.dispose();
  }

  void _enableFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() => _isFullscreen = true);
  }

  void _disableFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() => _isFullscreen = false);
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      _tapCount++;
      if (_tapCount == 2) {
        // 双击切换全屏
        if (_isFullscreen) {
          _disableFullscreen();
        } else {
          _enableFullscreen();
        }
        _tapCount = 0;
      }
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;
  }

  void _handleThreeFingerGesture() {
    final provider = context.read<PSStreamProvider>();
    if (provider.settings.showControllerAlways) return;

    setState(() {
      _showController = !_showController;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<PSStreamProvider>(
        builder: (context, provider, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // 视频显示区域
              GestureDetector(
                onTap: _handleTap,
                onScaleStart: (details) {
                  if (details.pointerCount == 3) {
                    _handleThreeFingerGesture();
                  }
                },
                child: _buildVideoView(provider),
              ),

              // 顶部状态栏
              if (!_isFullscreen || provider.stats != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildStatusBar(provider),
                ),

              // 虚拟控制器
              if (_showController || provider.settings.showControllerAlways)
                Positioned.fill(
                  child: VirtualController(
                    opacity: provider.settings.controllerOpacity,
                    onButtonChanged: (button, pressed) {
                      if (pressed) {
                        provider.pressButton(button);
                      } else {
                        provider.releaseButton(button);
                      }
                    },
                    onStickChanged: (stick, x, y) {
                      provider.updateStick(stick, x, y);
                    },
                    onTriggerChanged: (trigger, value) {
                      provider.updateTrigger(trigger, value);
                    },
                  ),
                ),

              // 加载/错误提示
              if (provider.isConnecting)
                _buildLoadingOverlay(),

              if (provider.error != null)
                _buildErrorOverlay(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoView(PSStreamProvider provider) {
    if (!provider.isConnected && !provider.isConnecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              '未连接',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
          ],
        ),
      );
    }

    // 这里应该集成实际的视频渲染组件
    // 例如使用 flutter_vlc_player 或其他视频播放器
    return StreamBuilder<List<int>>(
      stream: provider.videoStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(AppColors.primaryColor),
            ),
          );
        }

        // TODO: 实际渲染视频帧
        // 这里需要集成 H.264/HEVC 解码器和渲染器
        return Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              '视频流',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(PSStreamProvider provider) {
    final stats = provider.stats;
    final state = provider.sessionState;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // 返回按钮
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                final shouldExit = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('断开连接?'),
                    content: const Text('确定要停止串流并返回吗?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('确定'),
                      ),
                    ],
                  ),
                );

                if (shouldExit == true && mounted) {
                  await provider.stopStreaming();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
            ),

            const SizedBox(width: 16),

            // 连接状态
            _buildStatusChip(
              _getStateLabel(state),
              _getStateColor(state),
            ),

            const Spacer(),

            // 统计信息
            if (stats != null) ...[
              _buildStatItem(
                Icons.speed,
                '${stats.latencyMs}ms',
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                Icons.videocam,
                '${stats.fps.toStringAsFixed(0)} FPS',
              ),
              const SizedBox(width: 16),
              _buildStatItem(
                Icons.network_check,
                '${(stats.videoBitrate / 1000).toStringAsFixed(1)} Mbps',
              ),
            ],

            // 菜单按钮
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                _showStreamMenu(provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(AppColors.primaryColor),
            ),
            SizedBox(height: 24),
            Text(
              '正在连接...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(PSStreamProvider provider) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(AppColors.errorColor),
              ),
              const SizedBox(height: 24),
              Text(
                provider.error ?? '未知错误',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  provider.clearError();
                  Navigator.of(context).pop();
                },
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStreamMenu(PSStreamProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(AppColors.cardColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.gamepad),
              title: const Text('切换控制器'),
              onTap: () {
                Navigator.pop(context);
                _handleThreeFingerGesture();
              },
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: Text(_isFullscreen ? '退出全屏' : '全屏'),
              onTap: () {
                Navigator.pop(context);
                if (_isFullscreen) {
                  _disableFullscreen();
                } else {
                  _enableFullscreen();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, Routes.settings);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(AppColors.errorColor)),
              title: const Text(
                '断开连接',
                style: TextStyle(color: Color(AppColors.errorColor)),
              ),
              onTap: () async {
                Navigator.pop(context);
                await provider.stopStreaming();
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _getStateLabel(SessionState state) {
    switch (state) {
      case SessionState.disconnected:
        return '已断开';
      case SessionState.connecting:
        return '连接中';
      case SessionState.authenticating:
        return '认证中';
      case SessionState.streaming:
        return '串流中';
      case SessionState.paused:
        return '已暂停';
      case SessionState.error:
        return '错误';
    }
  }

  Color _getStateColor(SessionState state) {
    switch (state) {
      case SessionState.disconnected:
        return Colors.grey;
      case SessionState.connecting:
      case SessionState.authenticating:
        return const Color(AppColors.warningColor);
      case SessionState.streaming:
        return const Color(AppColors.successColor);
      case SessionState.paused:
        return const Color(AppColors.warningColor);
      case SessionState.error:
        return const Color(AppColors.errorColor);
    }
  }
}
