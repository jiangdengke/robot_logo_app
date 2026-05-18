import 'dart:async';
import 'dart:io';

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
  static const String accessCode = '2580';
  static const Duration idleTimeout = Duration(seconds: 15);
  static const Duration passwordTimeout = Duration(seconds: 20);
  static const String logoPathKey = 'robot_logo_image_path';
}

enum AppScreenState { idle, password, main }

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
  bool _isPickingLogo = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSavedLogo();
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
      if (_isPickingLogo) {
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

  void _appendPasswordDigit(String digit) {
    if (_screenState != AppScreenState.password) {
      return;
    }
    if (_passwordController.text.length >= AppConfig.accessCode.length) {
      return;
    }

    setState(() {
      _passwordController.text = '${_passwordController.text}$digit';
      _errorText = null;
    });

    if (_passwordController.text.length == AppConfig.accessCode.length) {
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
    if (_passwordController.text == AppConfig.accessCode) {
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
                  isPickingLogo: _isPickingLogo,
                  onPickLogo: _pickLogoImage,
                  onClearLogo: _clearLogoImage,
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
    required this.onTapEnter,
  });

  final String? logoImagePath;
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
    required this.emptyIcon,
    required this.emptyText,
  });

  final String? imagePath;
  final IconData emptyIcon;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    if (!hasImage) {
      return _LogoEmptyState(icon: emptyIcon, text: emptyText);
    }

    return Image.file(
      File(imagePath!),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _LogoEmptyState(icon: emptyIcon, text: emptyText);
      },
    );
  }
}

class _LogoFrame extends StatelessWidget {
  const _LogoFrame({
    required this.imagePath,
    required this.emptyIcon,
    required this.emptyText,
  });

  final String? imagePath;
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
            ? Image.file(
                File(imagePath!),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _LogoEmptyState(icon: emptyIcon, text: emptyText);
                },
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

class MainView extends StatelessWidget {
  const MainView({
    super.key,
    required this.logoImagePath,
    required this.isPickingLogo,
    required this.onPickLogo,
    required this.onClearLogo,
    required this.onExit,
  });

  final String? logoImagePath;
  final bool isPickingLogo;
  final VoidCallback onPickLogo;
  final VoidCallback onClearLogo;
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
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 560,
                          maxHeight: 420,
                        ),
                        child: _LogoFrame(
                          imagePath: logoImagePath,
                          emptyIcon: Icons.image_rounded,
                          emptyText: '尚未选择图片',
                        ),
                      ),
                    ),
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
