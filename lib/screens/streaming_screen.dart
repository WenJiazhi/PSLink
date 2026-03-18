import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/constants.dart';
import '../providers/device_provider.dart';
import '../providers/stream_provider.dart';
import '../services/streaming_service.dart';
import '../widgets/virtual_controller.dart';

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
  VlcPlayerController? _vlcController;
  String? _vlcUrl;
  bool _playerSyncPending = false;

  @override
  void initState() {
    super.initState();
    _setFullscreen(true);
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSelectedDeviceStream();
    });
  }

  Future<void> _startSelectedDeviceStream() async {
    final device = context.read<DeviceProvider>().selectedDevice;
    final streamProvider = context.read<PSStreamProvider>();
    if (device == null ||
        streamProvider.isConnected ||
        streamProvider.isConnecting) {
      return;
    }
    await streamProvider.startStreaming(device);
  }

  @override
  void dispose() {
    final controller = _vlcController;
    _vlcController = null;
    controller?.dispose();
    _restoreSystemUi();
    WakelockPlus.disable();
    super.dispose();
  }

  void _setFullscreen(bool enabled) {
    if (enabled) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      _restoreSystemUi();
    }

    if (mounted) {
      setState(() => _isFullscreen = enabled);
    } else {
      _isFullscreen = enabled;
    }
  }

  void _restoreSystemUi() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      _tapCount++;
      if (_tapCount == 2) {
        _setFullscreen(!_isFullscreen);
        _tapCount = 0;
      }
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;
  }

  void _handleThreeFingerGesture() {
    final provider = context.read<PSStreamProvider>();
    if (provider.settings.showControllerAlways) {
      return;
    }
    setState(() {
      _showController = !_showController;
    });
  }

  Future<void> _leaveStream(PSStreamProvider provider) async {
    await provider.stopStreaming();
    provider.clearError();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<PSStreamProvider>(
        builder: (context, provider, child) {
          _syncPlayer(provider.videoStreamUrl);
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: _handleTap,
                onScaleStart: (details) {
                  if (details.pointerCount == 3) {
                    _handleThreeFingerGesture();
                  }
                },
                child: _buildVideoView(provider),
              ),
              if (!_isFullscreen || provider.stats != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildStatusBar(provider),
                ),
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
                    onStickChanged: provider.updateStick,
                    onTriggerChanged: provider.updateTrigger,
                  ),
                ),
              if (provider.isConnecting) _buildLoadingOverlay(),
              if (provider.error != null) _buildErrorOverlay(provider),
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
              '尚未连接',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
          ],
        ),
      );
    }

    if (_vlcController != null) {
      return VlcPlayer(
        controller: _vlcController!,
        aspectRatio: 16 / 9,
        placeholder: const Center(
          child: CircularProgressIndicator(
            color: Color(AppColors.primaryColor),
          ),
        ),
      );
    }

    return StreamBuilder<Uint8List>(
      stream: provider.videoStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(AppColors.primaryColor),
            ),
          );
        }

        return Container(
          color: Colors.black,
          child: const Center(
            child: Text(
              '已接收视频数据，正在等待播放器建立连接…',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        );
      },
    );
  }

  void _syncPlayer(String? url) {
    if (_playerSyncPending) {
      return;
    }

    if (url == null || url.isEmpty) {
      if (_vlcController == null) {
        return;
      }
      _playerSyncPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final oldController = _vlcController;
        _vlcController = null;
        _vlcUrl = null;
        if (mounted) {
          setState(() {});
        }
        await oldController?.dispose();
        _playerSyncPending = false;
      });
      return;
    }

    if (_vlcUrl == url) {
      return;
    }

    _playerSyncPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final oldController = _vlcController;
      final controller = VlcPlayerController.network(
        url,
        autoPlay: true,
        hwAcc: HwAcc.auto,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            VlcAdvancedOptions.networkCaching(100),
            VlcAdvancedOptions.liveCaching(100),
          ]),
        ),
      );
      _vlcController = controller;
      _vlcUrl = url;
      if (mounted) {
        setState(() {});
      }
      await oldController?.dispose();
      _playerSyncPending = false;
    });
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
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () async {
                final shouldExit = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('断开连接'),
                    content: const Text('确定要停止串流并返回吗？'),
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

                if (shouldExit == true) {
                  await _leaveStream(provider);
                }
              },
            ),
            const SizedBox(width: 12),
            _buildStatusChip(
              _getStateLabel(state),
              _getStateColor(state),
            ),
            const Spacer(),
            if (stats != null) ...[
              _buildStatItem(Icons.speed, '${stats.latencyMs} ms'),
              const SizedBox(width: 16),
              _buildStatItem(Icons.videocam, '${stats.fps.toStringAsFixed(0)} FPS'),
              const SizedBox(width: 16),
              _buildStatItem(
                Icons.network_check,
                '${(stats.videoBitrate / 1000).toStringAsFixed(1)} Mbps',
              ),
            ],
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () => _showStreamMenu(provider),
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
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
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
          padding: const EdgeInsets.all(32),
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
                onPressed: () => _leaveStream(provider),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStreamMenu(PSStreamProvider provider) {
    showModalBottomSheet<void>(
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
              title: const Text('切换虚拟手柄'),
              onTap: () {
                Navigator.pop(context);
                _handleThreeFingerGesture();
              },
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: Text(_isFullscreen ? '退出全屏' : '进入全屏'),
              onTap: () {
                Navigator.pop(context);
                _setFullscreen(!_isFullscreen);
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
              leading: const Icon(
                Icons.logout,
                color: Color(AppColors.errorColor),
              ),
              title: const Text(
                '断开连接',
                style: TextStyle(color: Color(AppColors.errorColor)),
              ),
              onTap: () async {
                Navigator.pop(context);
                await _leaveStream(provider);
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
      case SessionState.paused:
        return const Color(AppColors.warningColor);
      case SessionState.streaming:
        return const Color(AppColors.successColor);
      case SessionState.error:
        return const Color(AppColors.errorColor);
    }
  }
}
