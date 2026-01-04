import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/device_provider.dart';
import '../widgets/ps_device_card.dart';
import '../models/ps_device.dart';

/// 主页面
/// 显示已保存和发现的 PS 设备列表，包含搜索/刷新功能
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 初始化设备提供者
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeviceProvider>();
      provider.initialize();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // 导航到设置页面
    if (index == 1) {
      Navigator.pushNamed(context, Routes.settings);
    }
  }

  Future<void> _refreshDevices() async {
    final provider = context.read<DeviceProvider>();
    await provider.startDiscovery();
  }

  void _startDiscovery() {
    final provider = context.read<DeviceProvider>();
    provider.startDiscovery();
  }

  void _onDeviceTap(PSDevice device) {
    final provider = context.read<DeviceProvider>();
    provider.selectDevice(device);

    if (device.isRegistered) {
      // 已注册的设备，直接跳转到串流页面
      Navigator.pushNamed(context, Routes.streaming);
    } else {
      // 未注册的设备，跳转到注册页面
      Navigator.pushNamed(
        context,
        Routes.registration,
        arguments: device,
      );
    }
  }

  void _onDeviceLongPress(PSDevice device) {
    _showDeviceOptions(device);
  }

  void _showDeviceOptions(PSDevice device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(AppColors.cardColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildDeviceOptionsSheet(device),
    );
  }

  Widget _buildDeviceOptionsSheet(PSDevice device) {
    final provider = context.read<DeviceProvider>();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: Color(AppColors.textSecondary).withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 设备信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
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

          // 选项列表
          if (device.state == PSDeviceState.standby)
            ListTile(
              leading: Icon(
                Icons.power_settings_new,
                color: Color(AppColors.accentColor),
              ),
              title: const Text('唤醒设备'),
              onTap: () {
                Navigator.pop(context);
                provider.wakeDevice(device);
              },
            ),
          if (device.isRegistered)
            ListTile(
              leading: Icon(
                Icons.edit,
                color: Color(AppColors.textPrimary),
              ),
              title: const Text('修改昵称'),
              onTap: () {
                Navigator.pop(context);
                _showNicknameDialog(device);
              },
            ),
          if (!device.isRegistered)
            ListTile(
              leading: Icon(
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
              leading: Icon(
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
    final controller = TextEditingController(text: device.nickname);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改设备昵称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '输入设备昵称',
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
              final provider = context.read<DeviceProvider>();
              provider.updateDeviceNickname(device.hostId, controller.text);
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDevice(PSDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除设备'),
        content: Text('确定要删除设备 "${device.displayName}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final provider = context.read<DeviceProvider>();
              provider.deleteDevice(device.hostId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(AppColors.errorColor),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
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
        // 搜索按钮
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _showSearchDialog(),
        ),
        // 刷新按钮
        Consumer<DeviceProvider>(
          builder: (context, provider, child) {
            if (provider.isDiscovering) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(AppColors.accentColor),
                    ),
                  ),
                ),
              );
            }
            return IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startDiscovery,
            );
          },
        ),
      ],
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('搜索设备'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: '设备名称或IP地址',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          autofocus: true,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _refreshDevices,
      color: Color(AppColors.accentColor),
      child: Consumer<DeviceProvider>(
        builder: (context, provider, child) {
          if (provider.error != null) {
            return _buildErrorView(provider.error!);
          }

          final devices = _filterDevices(provider.allDevices);

          if (devices.isEmpty) {
            return _buildEmptyView(provider.isDiscovering);
          }

          return _buildDeviceList(devices, provider.selectedDevice);
        },
      ),
    );
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
            isSelected: device == selectedDevice,
            onTap: () => _onDeviceTap(device),
            onLongPress: () => _onDeviceLongPress(device),
            onWake: () {
              final provider = context.read<DeviceProvider>();
              provider.wakeDevice(device);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyView(bool isDiscovering) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 80,
            color: Color(AppColors.textSecondary).withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            isDiscovering ? '正在搜索设备...' : '未发现 PlayStation 设备',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Color(AppColors.textSecondary),
                ),
          ),
          const SizedBox(height: 16),
          Text(
            isDiscovering
                ? '请确保您的 PlayStation 已开机\n并连接到同一网络'
                : '点击刷新按钮开始搜索\n或长按添加手动设备',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (!isDiscovering) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startDiscovery,
              icon: const Icon(Icons.search),
              label: const Text('开始搜索'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Color(AppColors.errorColor),
            ),
            const SizedBox(height: 24),
            Text(
              '发生错误',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Color(AppColors.errorColor),
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                final provider = context.read<DeviceProvider>();
                provider.clearError();
                _startDiscovery();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
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
