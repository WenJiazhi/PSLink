import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:pslink/src/models/ps_host.dart';
import 'package:pslink/src/models/controller_state.dart';
import 'package:pslink/src/protocol/session.dart';
import 'package:pslink/src/services/controller_service.dart';
import 'package:pslink/src/services/psn_account_storage.dart';
import '../widgets/virtual_controller_overlay.dart';
import 'package:pslink/l10n/app_localizations.dart';

class StreamingScreen extends StatefulWidget {
  final PSHost host;

  const StreamingScreen({super.key, required this.host});

  @override
  State<StreamingScreen> createState() => _StreamingScreenState();
}

class _StreamingScreenState extends State<StreamingScreen>
    with TickerProviderStateMixin {
  PSSession? _session;
  final VirtualController _controller = VirtualController();

  bool _isConnecting = true;
  bool _isConnected = false;
  bool _showControls = true;
  bool _showVirtualController = true;
  String? _statusKey = 'connecting';  // Store key, not message
  String? _statusError;  // Store error detail separately

  // Stream stats
  int _fps = 0;
  int _bitrate = 0;
  int _latency = 0;

  Timer? _hideControlsTimer;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _initSession();
    _controller.start();

    // Hide system UI for fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _statsTimer?.cancel();
    _session?.dispose();
    _controller.dispose();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    super.dispose();
  }

  Future<void> _initSession() async {
    try {
      // Load saved PSN Account ID or use default
      final psnAccountId = await PSNAccountStorage.getPSNAccountId() ??
                           PSNAccountStorage.getDefaultAccountId();

      _session = PSSession(
        host: widget.host,
        psnAccountId: psnAccountId,
        rpKey: widget.host.registrationInfo?.rpRegistKey ?? '',
      );

      _session!.eventStream.listen(_handleSessionEvent);

      await _session!.connect();

      _statsTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateStats(),
      );
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _statusKey = 'connectionFailed';
        _statusError = e.toString();
      });
    }
  }

  void _handleSessionEvent(SessionEvent event) {
    switch (event.type) {
      case SessionEventType.stateChanged:
        _handleStateChange(event.data as SessionState);
        break;
      case SessionEventType.videoFrame:
        // Handle video frame
        break;
      case SessionEventType.audioFrame:
        // Handle audio frame
        break;
      case SessionEventType.controllerFeedback:
        // Handle haptic feedback
        break;
      case SessionEventType.error:
        setState(() {
          _statusKey = 'unknownError';
          _statusError = event.message;
        });
        break;
    }
  }

  void _handleStateChange(SessionState state) {
    setState(() {
      switch (state) {
        case SessionState.connecting:
          _statusKey = 'connecting';
          _statusError = null;
          break;
        case SessionState.handshaking:
          _statusKey = 'authenticating';
          _statusError = null;
          break;
        case SessionState.authenticated:
          _statusKey = 'startingStream';
          _statusError = null;
          break;
        case SessionState.streaming:
          _isConnecting = false;
          _isConnected = true;
          _statusKey = null;
          _statusError = null;
          break;
        case SessionState.disconnecting:
          _statusKey = 'disconnecting';
          _statusError = null;
          break;
        case SessionState.disconnected:
          _isConnected = false;
          _statusKey = 'disconnected';
          _statusError = null;
          break;
        case SessionState.error:
          _isConnecting = false;
          _isConnected = false;
          break;
      }
    });
  }

  void _updateStats() {
    // Update streaming stats
    setState(() {
      _fps = 60; // Placeholder
      _bitrate = 10000; // kbps placeholder
      _latency = _session?.rttUs ?? 0;
    });
  }

  String _getStatusMessage(AppLocalizations l10n) {
    if (_statusKey == null) return '';

    final message = l10n.get(_statusKey!);
    if (_statusError != null) {
      return '$message: $_statusError';
    }
    return message;
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    setState(() {
      _showControls = true;
    });
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (_isConnected && mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _resetHideTimer,
        child: Stack(
          children: [
            // Video layer
            _buildVideoLayer(),

            // Virtual controller overlay
            if (_showVirtualController && _isConnected)
              VirtualControllerOverlay(
                controller: _controller,
                onControllerStateChanged: _sendControllerState,
              ),

            // Connection overlay
            if (_isConnecting || !_isConnected) _buildConnectionOverlay(),

            // Top controls
            if (_showControls) _buildTopControls(),

            // Bottom controls
            if (_showControls && _isConnected) _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLayer() {
    // Placeholder for video stream
    return Container(
      color: Colors.black,
      child: Center(
        child: _isConnected
            ? Container(
                color: const Color(0xFF1A1A1A),
                child: Center(
                  child: Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n.get('videoStream'),
                        style: const TextStyle(color: Colors.white54),
                      );
                    },
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildConnectionOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isConnecting) ...[
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0072CE), Color(0xFF00246B)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0072CE).withValues(alpha: 0.4),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: CupertinoActivityIndicator(
                        color: Colors.white,
                        radius: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  _getStatusMessage(l10n),
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                if (!_isConnecting)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        l10n.get('goBack'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
        ),
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
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: _disconnect,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Host name
            Expanded(
              child: Text(
                widget.host.hostName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Stats
            if (_isConnected) ...[
              _buildStatBadge('$_fps FPS'),
              const SizedBox(width: 8),
              _buildStatBadge('${_bitrate}k'),
              const SizedBox(width: 8),
              _buildStatBadge('${(_latency / 1000).toStringAsFixed(1)}ms'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Toggle virtual controller
              _buildBottomButton(
                icon: _showVirtualController
                    ? CupertinoIcons.game_controller_solid
                    : CupertinoIcons.game_controller,
                onPressed: () {
                  setState(() {
                    _showVirtualController = !_showVirtualController;
                  });
                },
              ),
              const SizedBox(width: 16),

              // Microphone
              _buildBottomButton(
                icon: CupertinoIcons.mic_off,
                onPressed: () {
                  // Toggle microphone
                },
              ),
              const SizedBox(width: 16),

              // Keyboard
              _buildBottomButton(
                icon: CupertinoIcons.keyboard,
                onPressed: () {
                  // Show keyboard
                },
              ),
              const SizedBox(width: 16),

              // Settings
              _buildBottomButton(
                icon: CupertinoIcons.settings,
                onPressed: _showStreamSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  void _sendControllerState(ControllerState state) {
    // Send controller state to session
    // This would be implemented in the streaming protocol
  }

  void _disconnect() {
    final l10n = AppLocalizations.of(context);
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.get('disconnect')),
        content: Text(l10n.get('endRemotePlaySession')),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.get('cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _session?.disconnect();
              Navigator.pop(context);
            },
            child: Text(l10n.get('disconnect')),
          ),
        ],
      ),
    );
  }

  void _showStreamSettings() {
    final l10n = AppLocalizations.of(context);
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.get('streamSettings'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            _buildSettingRow(
              l10n.get('resolution'),
              '1080p',
              onTap: () {},
            ),
            _buildSettingRow(
              l10n.get('frameRate'),
              '60 FPS',
              onTap: () {},
            ),
            _buildSettingRow(
              l10n.get('bitrateLimit'),
              l10n.get('bitrateAuto'),
              onTap: () {},
            ),
            _buildSettingRow(
              l10n.get('videoCodec'),
              'H.264',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
