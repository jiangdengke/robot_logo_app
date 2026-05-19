# Robot Logo App

一个用于送餐机器人主屏待机展示客户 Logo 的 Flutter Android 应用。

应用启动后默认进入待机页，主屏显示 Logo。触摸屏幕后进入密码页，输入密码后进入管理界面，可选择或清除当前 Logo 图片。

## 功能

- 待机页全屏展示客户 Logo。
- 触摸待机页后进入密码输入页。
- 密码正确后进入管理界面。
- 支持从本机相册/文件中选择 Logo 图片。
- 选中的 Logo 会复制到应用本地目录，重启后继续显示。
- 支持清除已选择的 Logo。
- 支持在主界面修改密码，并保存到本机。
- Android 包名：`com.jiangdengke.robotlogoapp`。

## 默认配置

- 默认密码：`2580`
- 待机超时：`15` 秒
- 密码页超时：`20` 秒
- 当前版本：`1.0.2+3`

相关配置目前在 [lib/main.dart](lib/main.dart) 的 `AppConfig` 中：

```dart
class AppConfig {
  static const String accessCode = '2580';
  static const Duration idleTimeout = Duration(seconds: 15);
  static const Duration passwordTimeout = Duration(seconds: 20);
}
```

## 使用流程

1. 安装 APK 到机器人或 Android 设备。
2. 打开应用后进入待机页。
3. 触摸屏幕进入密码页。
4. 输入默认密码 `2580`。
5. 在主界面点击 `选择 Logo`。
6. 选择客户 Logo 图片。
7. 点击 `返回待机页`，待机页会显示刚选择的 Logo。
8. 如需修改密码，点击 `修改密码`，输入旧密码和新密码后保存。

如果需要更换 Logo，重复进入主界面后重新选择图片即可。  
如果需要恢复默认占位图，点击 `清除 Logo`。
如果需要修改密码，点击 `修改密码` 后按提示操作。

## 本地开发

项目使用 Flutter 开发。

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

构建 release APK：

```bash
flutter build apk --release
```

构建产物路径：

```text
build/app/outputs/flutter-apk/app-release.apk
```

## 发版

GitHub Actions 只在推送 `v*` 标签时自动构建 APK 并创建 GitHub Release。

发布新版本示例：

```bash
git tag v1.0.2
git push origin v1.0.2
```

如果需要先升级应用版本号，修改 [pubspec.yaml](pubspec.yaml)：

```yaml
version: 1.0.2+3
```

## 适用场景

适用于可以安装 Android APK 的送餐机器人、迎宾机器人、展示屏或平板设备。当前设计目标是作为机器人主屏的 Logo 待机展示页，不负责替代机器人厂商原生系统。
