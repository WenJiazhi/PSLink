# PSLink 测试套件

本目录包含 PSLink Flutter 应用的完整测试套件。

## 测试文件结构

```
test/
├── models/
│   ├── ps_device_test.dart          (514 行) - PSDevice 模型测试
│   └── controller_state_test.dart   (580 行) - ControllerState 测试
├── services/
│   └── discovery_service_test.dart  (482 行) - DiscoveryService 测试
└── widgets/
    └── virtual_controller_test.dart (613 行) - VirtualController Widget 测试

总计: 2189 行测试代码
```

## 运行测试

### 前置步骤

1. 生成必要的 Mock 文件:

```bash
flutter pub run build_runner build
```

这将生成 `discovery_service_test.mocks.dart` 文件。

### 运行所有测试

```bash
# 运行所有测试
flutter test

# 运行并显示详细输出
flutter test --reporter expanded
```

### 运行特定测试文件

```bash
# 测试 PSDevice 模型
flutter test test/models/ps_device_test.dart

# 测试 ControllerState
flutter test test/models/controller_state_test.dart

# 测试 DiscoveryService
flutter test test/services/discovery_service_test.dart

# 测试 VirtualController Widget
flutter test test/widgets/virtual_controller_test.dart
```

### 查看测试覆盖率

```bash
# 生成覆盖率报告
flutter test --coverage

# 生成 HTML 报告 (需要安装 lcov)
genhtml coverage/lcov.info -o coverage/html
```

## 测试覆盖范围

### 1. PSDevice 模型测试 (test/models/ps_device_test.dart)

- ✅ 创建 PS4/PS5 设备
- ✅ 设备状态和类型转换
- ✅ JSON 序列化/反序列化
- ✅ fromDiscoveryResponse 解析
- ✅ copyWith 功能
- ✅ equals 和 hashCode
- ✅ toString 输出

**测试组数**: 8 组
**测试用例**: 40+ 个

### 2. ControllerState 测试 (test/models/controller_state_test.dart)

- ✅ 按钮状态 (17个按钮)
- ✅ 摇杆输入 (左右摇杆)
- ✅ 触发器 (L2/R2)
- ✅ 触摸板和传感器数据
- ✅ toBytes 序列化 (二进制协议)
- ✅ copyWith 功能
- ✅ toString 输出

**测试组数**: 4 组
**测试用例**: 50+ 个

**关键测试**:
- 按钮位掩码编码验证
- 模拟轴值的 16 位有符号整数编码
- 触发器值的 0-255 范围限制
- 完整状态的 14 字节数据包验证

### 3. DiscoveryService 测试 (test/services/discovery_service_test.dart)

- ✅ 服务初始化状态
- ✅ 发现请求格式验证
- ✅ UDP 广播配置
- ✅ 响应解析 (HTTP-like 格式)
- ✅ PS4/PS5 设备识别
- ✅ 状态码处理 (200=ready, 620=standby)
- ✅ 唤醒请求格式
- ✅ 边界情况和错误处理

**测试组数**: 9 组
**测试用例**: 40+ 个

**协议验证**:
- SRCH 发现请求格式
- WAKEUP 唤醒请求格式
- HTTP/1.1 响应解析
- 协议版本 00030010

### 4. VirtualController Widget 测试 (test/widgets/virtual_controller_test.dart)

- ✅ Widget 渲染
- ✅ 按钮交互 (Cross, Circle, Square, Triangle)
- ✅ 方向键交互
- ✅ 肩键和触发器
- ✅ 摇杆拖动和释放
- ✅ 回调触发验证
- ✅ 无回调安全性
- ✅ 视觉样式验证
- ✅ 状态管理
- ✅ 响应式布局

**测试组数**: 8 组
**测试用例**: 30+ 个

## 测试工具

### 使用的测试框架

- **flutter_test**: Flutter 官方测试框架
- **mockito**: Mock 对象生成 (用于 DiscoveryService)

### Mock 对象

DiscoveryService 测试使用 Mockito 生成 Mock:

```dart
@GenerateMocks([RawDatagramSocket])
```

运行以下命令生成 Mock 类:

```bash
flutter pub run build_runner build
```

这会生成 `test/services/discovery_service_test.mocks.dart`。

## 常见问题

### Q: Mock 文件找不到

**A**: 运行 `flutter pub run build_runner build` 生成 Mock 文件。

### Q: 测试失败

**A**: 确保:
1. 所有依赖已安装 (`flutter pub get`)
2. Mock 文件已生成
3. 模型的 `.g.dart` 文件已生成 (如果使用 Hive)

### Q: 如何调试失败的测试

**A**: 使用 `--reporter expanded` 查看详细输出:

```bash
flutter test test/models/ps_device_test.dart --reporter expanded
```

## 持续集成 (CI)

在 CI 环境中运行测试:

```yaml
# .github/workflows/test.yml
- name: Run tests
  run: |
    flutter pub get
    flutter pub run build_runner build --delete-conflicting-outputs
    flutter test --coverage
```

## 贡献指南

添加新测试时:

1. 遵循现有的测试结构和命名约定
2. 使用描述性的测试名称
3. 每个测试应该测试一个具体功能
4. 使用 `group()` 组织相关测试
5. 添加边界情况和错误处理测试

## 测试最佳实践

1. **单一职责**: 每个测试只验证一个行为
2. **独立性**: 测试之间不应相互依赖
3. **可读性**: 使用清晰的测试名称和断言消息
4. **完整性**: 测试正常路径和异常路径
5. **维护性**: 避免重复代码,使用 setUp/tearDown

## 许可证

与主项目相同
