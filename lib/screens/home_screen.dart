import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../models/ps_device.dart';
import '../providers/device_provider.dart';
import '../widgets/ps_device_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeviceProvider>();
      provider.initialize();
      provider.startDiscovery();
    });
  }

  Future<void> _refreshDevices() async {
    await context.read<DeviceProvider>().startDiscovery();
  }

  Future<void> _startDiscovery() async {
    await context.read<DeviceProvider>().startDiscovery();
  }

  void _onDeviceTap(PSDevice device) {
    final provider = context.read<DeviceProvider>();
    provider.selectDevice(device);

    if (device.isRegistered) {
      Navigator.pushNamed(context, Routes.streaming);
      return;
    }

    Navigator.pushNamed(
      context,
      Routes.registration,
      arguments: device,
    );
  }

  Future<void> _wakeDevice(PSDevice device) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await context.read<DeviceProvider>().wakeDevice(device);
    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '已向 ${device.displayName} 发送唤醒请求。'
              : '唤醒失败，请确认设备已注册并处于待机状态。',
        ),
      ),
    );
  }

  void _onDeviceLongPress(PSDevice device) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(AppColors.cardColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildDeviceOptionsSheet(device),
    );
  }

  Widget _buildDeviceOptionsSheet(PSDevice device) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: const Color(AppColors.textSecondary).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_esports,
                  color: Color(AppColors.accentColor),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        device.ipAddress,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          if (device.state == PSDeviceState.standby)
            ListTile(
              leading: const Icon(
                Icons.power_settings_new,
                color: Color(AppColors.accentColor),
              ),
              title: const Text('唤醒设备'),
              onTap: () {
                Navigator.pop(context);
                _wakeDevice(device);
              },
            ),
          if (device.isRegistered)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('修改名称'),
              onTap: () {
                Navigator.pop(context);
                _showNicknameDialog(device);
              },
            ),
          if (!device.isRegistered)
            ListTile(
              leading: const Icon(
                Icons.app_registration,
                color: Color(AppColors.accentColor),
              ),
              title: const Text('注册设备'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  Routes.registration,
                  arguments: device,
                );
              },
            ),
          if (device.isRegistered)
            ListTile(
              leading: const Icon(
                Icons.delete,
                color: Color(AppColors.errorColor),
              ),
              title: const Text('删除设备'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteDevice(device);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showNicknameDialog(PSDevice device) {
    final controller = TextEditingController(text: device.nickname ?? '');

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改设备名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '输入便于识别的名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<DeviceProvider>().updateDeviceNickname(
                    device.hostId,
                    controller.text.trim(),
                  );
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDevice(PSDevice device) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除设备'),
        content: Text('确定要删除“${device.displayName}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(AppColors.errorColor),
            ),
            onPressed: () {
              context.read<DeviceProvider>().deleteDevice(device.hostId);
              Navigator.pop(context);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSearchDialog() async {
    final controller = TextEditingController(text: _searchQuery);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选设备'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '设备名称或 IP 地址',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
              Navigator.pop(context);
            },
            child: const Text('清除'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchQuery = controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualAddDialog() async {
    final controller = TextEditingController();
    final host = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动添加主机'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'IP 地址或主机名',
            hintText: '例如 192.168.1.23',
            prefixIcon: Icon(Icons.add_link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('探测'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || host == null || host.isEmpty) {
      return;
    }

    final provider = context.read<DeviceProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final device = await provider.probeDevice(host);

    if (!mounted) {
      return;
    }

    if (device == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.error ?? '没有发现可连接的 PlayStation 主机。'),
        ),
      );
      provider.clearError();
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('已发现 ${device.displayName} (${device.ipAddress})'),
      ),
    );
    _onDeviceTap(device);
  }

  List<PSDevice> _filterDevices(List<PSDevice> devices) {
    if (_searchQuery.isEmpty) {
      return devices;
    }

    final query = _searchQuery.toLowerCase();
    return devices.where((device) {
      return device.displayName.toLowerCase().contains(query) ||
          device.ipAddress.contains(query) ||
          device.hostId.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('PSLink'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: '筛选',
          onPressed: _showSearchDialog,
        ),
        IconButton(
          icon: const Icon(Icons.add_link),
          tooltip: '手动添加主机',
          onPressed: _showManualAddDialog,
        ),
        Consumer<DeviceProvider>(
          builder: (context, provider, child) {
            if (provider.isDiscovering) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(AppColors.accentColor),
                  ),
                ),
              );
            }

            return IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重新搜索',
              onPressed: _startDiscovery,
            );
          },
        ),
      ],
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _refreshDevices,
      color: const Color(AppColors.accentColor),
      child: Consumer<DeviceProvider>(
        builder: (context, provider, child) {
          final devices = _filterDevices(provider.allDevices);

          if (devices.isEmpty) {
            if (provider.error != null && !provider.isDiscovering) {
              return _buildErrorView(provider.error!);
            }
            return _buildEmptyView(provider.isDiscovering);
          }

          return _buildDeviceList(devices, provider.selectedDevice);
        },
      ),
    );
  }

  Widget _buildDeviceList(List<PSDevice> devices, PSDevice? selectedDevice) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PSDeviceCard(
            device: device,
            isSelected: device.hostId == selectedDevice?.hostId,
            onTap: () => _onDeviceTap(device),
            onLongPress: () => _onDeviceLongPress(device),
            onWake: () => _wakeDevice(device),
          ),
        );
      },
    );
  }

  Widget _buildEmptyView(bool isDiscovering) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices_other,
                    size: 80,
                    color: const Color(AppColors.textSecondary).withValues(
                      alpha: 0.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isDiscovering ? '正在搜索主机...' : '未发现 PlayStation 主机',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: const Color(AppColors.textSecondary),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isDiscovering
                        ? '请确认 PS5 / PS4 已开启 Remote Play，并与当前设备处于同一局域网。'
                        : '如果自动发现失败，可以重新搜索，或直接手动输入主机 IP 地址进行探测。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: isDiscovering ? null : _startDiscovery,
                        icon: const Icon(Icons.search),
                        label: const Text('重新搜索'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showManualAddDialog,
                        icon: const Icon(Icons.add_link),
                        label: const Text('手动添加 IP'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(String error) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Color(AppColors.errorColor),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '发现主机时出错',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: const Color(AppColors.errorColor),
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          context.read<DeviceProvider>().clearError();
                          _startDiscovery();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showManualAddDialog,
                        icon: const Icon(Icons.add_link),
                        label: const Text('手动添加 IP'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: 0,
      onTap: (index) {
        if (index == 1) {
          Navigator.pushNamed(context, Routes.settings);
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.devices),
          label: '设备',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: '设置',
        ),
      ],
    );
  }
}
