import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const RobotLogoApp());
}

class AppConfig {
  static const String appTitle = 'Robot Logo App';
  static const String defaultAccessCode = '2580';
  static const int minAccessCodeLength = 4;
  static const int maxAccessCodeLength = 8;
  static const Duration idleTimeout = Duration(seconds: 15);
  static const Duration passwordTimeout = Duration(seconds: 20);
  static const String logoPathKey = 'robot_logo_image_path';
  static const String accessCodeKey = 'robot_access_code';
  static const String logoFitKey = 'robot_logo_fit';
  static const String logoRotationKey = 'robot_logo_rotation';
}

enum AppScreenState { idle, password, main }

enum LogoFitMode {
  contain('contain', '完整自适应'),
  cover('cover', '铺满裁剪'),
  fill('fill', '拉伸铺满');

  const LogoFitMode(this.storageValue, this.label);

  final String storageValue;
  final String label;

  BoxFit get boxFit {
    return switch (this) {
      LogoFitMode.contain => BoxFit.contain,
      LogoFitMode.cover => BoxFit.cover,
      LogoFitMode.fill => BoxFit.fill,
    };
  }

  static LogoFitMode fromStorageValue(String? value) {
    return LogoFitMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => LogoFitMode.contain,
    );
  }
}

class RobotLogoApp extends StatelessWidget {
  const RobotLogoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appTitle,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F3C88),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const RobotShell(),
    );
  }
}

class RobotShell extends StatefulWidget {
  const RobotShell({super.key});

  @override
  State<RobotShell> createState() => _RobotShellState();
}

class _RobotShellState extends State<RobotShell> {
  AppScreenState _screenState = AppScreenState.idle;
  final TextEditingController _passwordController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _idleTimer;
  Timer? _passwordTimer;
  String? _logoImagePath;
  String _accessCode = AppConfig.defaultAccessCode;
  LogoFitMode _logoFitMode = LogoFitMode.contain;
  int _logoRotationTurns = 0;
  bool _isPickingLogo = false;
  bool _isChangingPassword = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSavedLogo();
    _loadSavedAccessCode();
    _loadSavedLogoDisplayOptions();
    _restartIdleTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _passwordTimer?.cancel();
    _passwordController.dispose();
    super.dispose();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(AppConfig.idleTimeout, () {
      if (!mounted) {
        return;
      }
      if (_isPickingLogo || _isChangingPassword) {
        return;
      }
      _goToIdle();
    });
  }

  void _restartPasswordTimer() {
    _passwordTimer?.cancel();
    _passwordTimer = Timer(AppConfig.passwordTimeout, () {
      if (!mounted) {
        return;
      }
      _goToIdle();
    });
  }

  void _goToIdle() {
    _passwordTimer?.cancel();
    _passwordController.clear();
    setState(() {
      _screenState = AppScreenState.idle;
      _errorText = null;
    });
    _restartIdleTimer();
  }

  void _goToPassword() {
    _idleTimer?.cancel();
    _passwordController.clear();
    setState(() {
      _screenState = AppScreenState.password;
      _errorText = null;
    });
    _restartPasswordTimer();
  }

  Future<void> _loadSavedLogo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(AppConfig.logoPathKey);
    if (savedPath == null || savedPath.isEmpty) {
      return;
    }

    final exists = await File(savedPath).exists();
    if (!mounted) {
      return;
    }

    if (exists) {
      setState(() {
        _logoImagePath = savedPath;
      });
      return;
    }

    await prefs.remove(AppConfig.logoPathKey);
  }

  Future<void> _loadSavedAccessCode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAccessCode = prefs.getString(AppConfig.accessCodeKey);
    if (!_isValidAccessCode(savedAccessCode)) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _accessCode = savedAccessCode!;
    });
  }

  Future<void> _loadSavedLogoDisplayOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFitMode = LogoFitMode.fromStorageValue(
      prefs.getString(AppConfig.logoFitKey),
    );
    final savedRotationTurns = _normalizeRotationTurns(
      prefs.getInt(AppConfig.logoRotationKey) ?? 0,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _logoFitMode = savedFitMode;
      _logoRotationTurns = savedRotationTurns;
    });
  }

  Future<void> _pickLogoImage() async {
    if (_isPickingLogo) {
      return;
    }

    setState(() {
      _isPickingLogo = true;
    });
    _idleTimer?.cancel();
    _passwordTimer?.cancel();

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (pickedImage == null) {
        return;
      }

      final appDirectory = await getApplicationDocumentsDirectory();
      final fileExtension = _imageExtensionFromPath(pickedImage.path);
      final fileName =
          'robot_logo_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final destination = File('${appDirectory.path}/$fileName');
      await pickedImage.saveTo(destination.path);

      final prefs = await SharedPreferences.getInstance();
      final previousPath = _logoImagePath;
      await prefs.setString(AppConfig.logoPathKey, destination.path);

      if (previousPath != null && previousPath != destination.path) {
        try {
          await File(previousPath).delete();
        } catch (_) {
          // Ignore stale file cleanup errors.
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _logoImagePath = destination.path;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Logo 已更新')));
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败：${error.message ?? '未知错误'}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingLogo = false;
        });
      }
      _restartIdleTimer();
      if (_screenState == AppScreenState.password) {
        _restartPasswordTimer();
      }
    }
  }

  Future<void> _clearLogoImage() async {
    final currentPath = _logoImagePath;
    if (currentPath == null) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.logoPathKey);

    try {
      await File(currentPath).delete();
    } catch (_) {
      // Ignore cleanup errors when the file is already gone.
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _logoImagePath = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Logo 已清除')));
  }

  String _imageExtensionFromPath(String path) {
    final lowerPath = path.toLowerCase();
    for (final extension in const ['.png', '.jpg', '.jpeg', '.webp', '.gif']) {
      if (lowerPath.endsWith(extension)) {
        return extension;
      }
    }
    return '.png';
  }

  bool _isValidAccessCode(String? value) {
    if (value == null) {
      return false;
    }

    final isValidLength =
        value.length >= AppConfig.minAccessCodeLength &&
        value.length <= AppConfig.maxAccessCodeLength;
    return isValidLength && RegExp(r'^\d+$').hasMatch(value);
  }

  int _normalizeRotationTurns(int value) {
    return value.remainder(4);
  }

  Future<void> _changeLogoFitMode(LogoFitMode fitMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.logoFitKey, fitMode.storageValue);

    if (!mounted) {
      return;
    }

    setState(() {
      _logoFitMode = fitMode;
    });
    _restartIdleTimer();
  }

  Future<void> _changeLogoRotationTurns(int turns) async {
    final normalizedTurns = _normalizeRotationTurns(turns);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConfig.logoRotationKey, normalizedTurns);

    if (!mounted) {
      return;
    }

    setState(() {
      _logoRotationTurns = normalizedTurns;
    });
    _restartIdleTimer();
  }

  Future<void> _showChangePasswordDialog() async {
    if (_isChangingPassword) {
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });
    _idleTimer?.cancel();
    _passwordTimer?.cancel();

    try {
      final newAccessCode = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return ChangePasswordDialog(currentAccessCode: _accessCode);
        },
      );
      if (newAccessCode == null) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConfig.accessCodeKey, newAccessCode);

      if (!mounted) {
        return;
      }

      setState(() {
        _accessCode = newAccessCode;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码已更新')));
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
      _restartIdleTimer();
    }
  }

  void _appendPasswordDigit(String digit) {
    if (_screenState != AppScreenState.password) {
      return;
    }
    if (_passwordController.text.length >= _accessCode.length) {
      return;
    }

    setState(() {
      _passwordController.text = '${_passwordController.text}$digit';
      _errorText = null;
    });

    if (_passwordController.text.length == _accessCode.length) {
      _unlock();
    }
  }

  void _backspacePasswordDigit() {
    if (_screenState != AppScreenState.password ||
        _passwordController.text.isEmpty) {
      return;
    }

    setState(() {
      _passwordController.text = _passwordController.text.substring(
        0,
        _passwordController.text.length - 1,
      );
      _errorText = null;
    });
  }

  void _clearPasswordBuffer() {
    if (_screenState != AppScreenState.password) {
      return;
    }

    setState(() {
      _passwordController.clear();
      _errorText = null;
    });
  }

  void _unlock() {
    if (_passwordController.text == _accessCode) {
      _passwordTimer?.cancel();
      setState(() {
        _screenState = AppScreenState.main;
        _errorText = null;
      });
      _restartIdleTimer();
      return;
    }

    setState(() {
      _errorText = '密码错误';
    });
    _passwordController.clear();
    _restartPasswordTimer();
  }

  void _backToIdleFromMain() {
    _goToIdle();
  }

  void _handleAnyTouch() {
    if (_screenState == AppScreenState.idle) {
      _goToPassword();
      return;
    }
    _restartIdleTimer();
    if (_screenState == AppScreenState.password) {
      _restartPasswordTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _handleAnyTouch(),
      child: PopScope(
        canPop: false,
        child: Scaffold(
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_screenState) {
              AppScreenState.idle => IdleView(
                key: const ValueKey('idle'),
                logoImagePath: _logoImagePath,
                logoFitMode: _logoFitMode,
                logoRotationTurns: _logoRotationTurns,
                onTapEnter: _goToPassword,
              ),
              AppScreenState.password => SafeArea(
                key: const ValueKey('password'),
                child: PasswordView(
                  key: const ValueKey('password'),
                  controller: _passwordController,
                  errorText: _errorText,
                  onSubmit: _unlock,
                  onDigit: _appendPasswordDigit,
                  onBackspace: _backspacePasswordDigit,
                  onClear: _clearPasswordBuffer,
                  onCancel: _goToIdle,
                ),
              ),
              AppScreenState.main => SafeArea(
                key: const ValueKey('main'),
                child: MainView(
                  key: const ValueKey('main'),
                  logoImagePath: _logoImagePath,
                  logoFitMode: _logoFitMode,
                  logoRotationTurns: _logoRotationTurns,
                  isPickingLogo: _isPickingLogo,
                  onPickLogo: _pickLogoImage,
                  onClearLogo: _clearLogoImage,
                  onLogoFitModeChanged: _changeLogoFitMode,
                  onLogoRotationChanged: _changeLogoRotationTurns,
                  onChangePassword: _showChangePasswordDialog,
                  onExit: _backToIdleFromMain,
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class IdleView extends StatelessWidget {
  const IdleView({
    super.key,
    required this.logoImagePath,
    required this.logoFitMode,
    required this.logoRotationTurns,
    required this.onTapEnter,
  });

  final String? logoImagePath;
  final LogoFitMode logoFitMode;
  final int logoRotationTurns;
  final VoidCallback onTapEnter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: InkWell(
        onTap: onTapEnter,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _FullscreenLogo(
              imagePath: logoImagePath,
              fitMode: logoFitMode,
              rotationTurns: logoRotationTurns,
              emptyIcon: Icons.storefront_rounded,
              emptyText: '请选择 Logo',
            ),
            if (logoImagePath == null || logoImagePath!.isEmpty)
              const Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Text(
                  '触摸屏幕进入',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Color(0xFF4A4A4A)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenLogo extends StatelessWidget {
  const _FullscreenLogo({
    required this.imagePath,
    required this.fitMode,
    required this.rotationTurns,
    required this.emptyIcon,
    required this.emptyText,
  });

  final String? imagePath;
  final LogoFitMode fitMode;
  final int rotationTurns;
  final IconData emptyIcon;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    if (!hasImage) {
      return _LogoEmptyState(icon: emptyIcon, text: emptyText);
    }

    return _RotatedLogo(
      rotationTurns: rotationTurns,
      child: Image.file(
        File(imagePath!),
        width: double.infinity,
        height: double.infinity,
        fit: fitMode.boxFit,
        errorBuilder: (context, error, stackTrace) {
          return _LogoEmptyState(icon: emptyIcon, text: emptyText);
        },
      ),
    );
  }
}

class _RotatedLogo extends StatelessWidget {
  const _RotatedLogo({required this.rotationTurns, required this.child});

  final int rotationTurns;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final normalizedTurns = rotationTurns.remainder(4);
    if (normalizedTurns == 0) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final quarterTurns = normalizedTurns.isOdd;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return ClipRect(
          child: Center(
            child: Transform.rotate(
              angle: normalizedTurns * math.pi / 2,
              child: SizedBox(
                width: quarterTurns ? height : width,
                height: quarterTurns ? width : height,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LogoFrame extends StatelessWidget {
  const _LogoFrame({
    required this.imagePath,
    required this.fitMode,
    required this.rotationTurns,
    required this.emptyIcon,
    required this.emptyText,
  });

  final String? imagePath;
  final LogoFitMode fitMode;
  final int rotationTurns;
  final IconData emptyIcon;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        color: const Color(0xFFF8FAFC),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: hasImage
            ? _RotatedLogo(
                rotationTurns: rotationTurns,
                child: Image.file(
                  File(imagePath!),
                  width: double.infinity,
                  height: double.infinity,
                  fit: fitMode.boxFit,
                  errorBuilder: (context, error, stackTrace) {
                    return _LogoEmptyState(icon: emptyIcon, text: emptyText);
                  },
                ),
              )
            : _LogoEmptyState(icon: emptyIcon, text: emptyText),
      ),
    );
  }
}

class _LogoEmptyState extends StatelessWidget {
  const _LogoEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 120, color: const Color(0xFF1F3C88)),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class PasswordView extends StatelessWidget {
  const PasswordView({
    super.key,
    required this.controller,
    required this.errorText,
    required this.onSubmit,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onCancel,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onSubmit;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '请输入密码',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: '••••',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _Keypad(
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                  onClear: onClear,
                  onConfirm: onSubmit,
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: onCancel, child: const Text('返回待机页')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.onConfirm,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final buttons = <String>[
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '清空',
      '0',
      '删除',
    ];

    return GridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: buttons.map((label) {
        final isDigit = RegExp(r'^\d$').hasMatch(label);
        final handler = switch (label) {
          '清空' => onClear,
          '删除' => onBackspace,
          _ => isDigit ? () => onDigit(label) : onConfirm,
        };

        return FilledButton.tonal(onPressed: handler, child: Text(label));
      }).toList(),
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key, required this.currentAccessCode});

  final String currentAccessCode;

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (oldPassword != widget.currentAccessCode) {
      setState(() {
        _errorText = '旧密码不正确';
      });
      return;
    }

    if (!_isValidNewPassword(newPassword)) {
      setState(() {
        _errorText =
            '新密码必须是 ${AppConfig.minAccessCodeLength}-${AppConfig.maxAccessCodeLength} 位数字';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorText = '两次输入的新密码不一致';
      });
      return;
    }

    if (newPassword == oldPassword) {
      setState(() {
        _errorText = '新密码不能和旧密码相同';
      });
      return;
    }

    Navigator.of(context).pop(newPassword);
  }

  bool _isValidNewPassword(String value) {
    final isValidLength =
        value.length >= AppConfig.minAccessCodeLength &&
        value.length <= AppConfig.maxAccessCodeLength;
    return isValidLength && RegExp(r'^\d+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final inputFormatters = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(AppConfig.maxAccessCodeLength),
    ];

    return AlertDialog(
      title: const Text('修改密码'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PasswordInputField(
                controller: _oldPasswordController,
                labelText: '旧密码',
                inputFormatters: inputFormatters,
              ),
              const SizedBox(height: 12),
              _PasswordInputField(
                controller: _newPasswordController,
                labelText: '新密码',
                inputFormatters: inputFormatters,
              ),
              const SizedBox(height: 12),
              _PasswordInputField(
                controller: _confirmPasswordController,
                labelText: '确认新密码',
                inputFormatters: inputFormatters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 10),
              Text(
                '${AppConfig.minAccessCodeLength}-${AppConfig.maxAccessCodeLength} 位数字，修改后立即生效。',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _PasswordInputField extends StatelessWidget {
  const _PasswordInputField({
    required this.controller,
    required this.labelText,
    required this.inputFormatters,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final List<TextInputFormatter> inputFormatters;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class LogoDisplayControls extends StatelessWidget {
  const LogoDisplayControls({
    super.key,
    required this.fitMode,
    required this.rotationTurns,
    required this.onFitModeChanged,
    required this.onRotationChanged,
  });

  final LogoFitMode fitMode;
  final int rotationTurns;
  final ValueChanged<LogoFitMode> onFitModeChanged;
  final ValueChanged<int> onRotationChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            SegmentedButton<LogoFitMode>(
              segments: LogoFitMode.values
                  .map(
                    (mode) => ButtonSegment<LogoFitMode>(
                      value: mode,
                      label: Text(mode.label),
                    ),
                  )
                  .toList(),
              selected: {fitMode},
              onSelectionChanged: (selection) {
                onFitModeChanged(selection.first);
              },
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(value: 0, label: Text('0°')),
                ButtonSegment<int>(value: 1, label: Text('90°')),
                ButtonSegment<int>(value: 2, label: Text('180°')),
                ButtonSegment<int>(value: 3, label: Text('270°')),
              ],
              selected: {rotationTurns.remainder(4)},
              onSelectionChanged: (selection) {
                onRotationChanged(selection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '显示方式和旋转角度会保存到本机，待机页同步生效。',
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class MainView extends StatelessWidget {
  const MainView({
    super.key,
    required this.logoImagePath,
    required this.logoFitMode,
    required this.logoRotationTurns,
    required this.isPickingLogo,
    required this.onPickLogo,
    required this.onClearLogo,
    required this.onLogoFitModeChanged,
    required this.onLogoRotationChanged,
    required this.onChangePassword,
    required this.onExit,
  });

  final String? logoImagePath;
  final LogoFitMode logoFitMode;
  final int logoRotationTurns;
  final bool isPickingLogo;
  final VoidCallback onPickLogo;
  final VoidCallback onClearLogo;
  final ValueChanged<LogoFitMode> onLogoFitModeChanged;
  final ValueChanged<int> onLogoRotationChanged;
  final VoidCallback onChangePassword;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '主界面',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: onExit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                child: const Text('返回待机页'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Logo 设置',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: _LogoFrame(
                            imagePath: logoImagePath,
                            fitMode: logoFitMode,
                            rotationTurns: logoRotationTurns,
                            emptyIcon: Icons.image_rounded,
                            emptyText: '尚未选择图片',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LogoDisplayControls(
                      fitMode: logoFitMode,
                      rotationTurns: logoRotationTurns,
                      onFitModeChanged: onLogoFitModeChanged,
                      onRotationChanged: onLogoRotationChanged,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: isPickingLogo ? null : onPickLogo,
                          icon: isPickingLogo
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.image_rounded),
                          label: Text(isPickingLogo ? '选择中...' : '选择 Logo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: logoImagePath == null || isPickingLogo
                              ? null
                              : onClearLogo,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('清除 Logo'),
                        ),
                        OutlinedButton.icon(
                          onPressed: isPickingLogo ? null : onChangePassword,
                          icon: const Icon(Icons.lock_reset_rounded),
                          label: const Text('修改密码'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '选中的图片会自动保存在本机，重启后仍然可用。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '这里放你们真正的操作界面',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
