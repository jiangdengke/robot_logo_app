import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
}

enum AppScreenState {
  idle,
  password,
  main,
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
  Timer? _idleTimer;
  Timer? _passwordTimer;
  String? _errorText;

  @override
  void initState() {
    super.initState();
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
      _passwordController.text =
          _passwordController.text.substring(0, _passwordController.text.length - 1);
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
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_screenState) {
                AppScreenState.idle => IdleView(
                    key: const ValueKey('idle'),
                    onTapEnter: _goToPassword,
                  ),
                AppScreenState.password => PasswordView(
                  key: const ValueKey('password'),
                  controller: _passwordController,
                  errorText: _errorText,
                  onSubmit: _unlock,
                  onDigit: _appendPasswordDigit,
                  onBackspace: _backspacePasswordDigit,
                  onClear: _clearPasswordBuffer,
                  onCancel: _goToIdle,
                ),
                AppScreenState.main => MainView(
                    key: const ValueKey('main'),
                    onExit: _backToIdleFromMain,
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class IdleView extends StatelessWidget {
  const IdleView({super.key, required this.onTapEnter});

  final VoidCallback onTapEnter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: InkWell(
        onTap: onTapEnter,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 220,
                      minHeight: 220,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.storefront_rounded,
                        size: 120,
                        color: Color(0xFF1F3C88),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                '触摸屏幕进入',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF4A4A4A),
                ),
              ),
            ),
          ],
        ),
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
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
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
                TextButton(
                  onPressed: onCancel,
                  child: const Text('返回待机页'),
                ),
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
    final buttons = <Widget>[
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

        return FilledButton.tonal(
          onPressed: handler,
          child: Text(label),
        );
      }).toList(),
    );
  }
}

class MainView extends StatelessWidget {
  const MainView({super.key, required this.onExit});

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
                child: const Text('返回 Logo'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  '这里放你们真正的操作界面',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
