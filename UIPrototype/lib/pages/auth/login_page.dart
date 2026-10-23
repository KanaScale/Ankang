import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../routes/app_router.dart';
import '../../routes/route_names.dart';
import '../../services/auth_service.dart';
import '../../services/reminder_notification_service.dart';
import '../../utils/auth_preferences.dart';
import '../../utils/toast_util.dart';
import '../../utils/validator_util.dart';
import '../../widgets/common/common_input.dart';
import '../../widgets/gradient_container.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/large_primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _keepSignedIn = false;

  @override
  void initState() {
    super.initState();
    _loadLoginPreference();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      final response = await _authService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        keepSignedIn: _keepSignedIn,
      );
      if (!mounted) {
        return;
      }
      if (response.success) {
        await AuthPreferences.saveKeepSignedIn(
          username: _usernameController.text.trim(),
          enabled: _keepSignedIn,
        );
        if (!mounted) {
          return;
        }
        final ownerUserId = AuthService.currentUser?.id;
        final target = ownerUserId == null
            ? null
            : ReminderNotificationService.takePendingNavigation(ownerUserId);
        AppRouter.replace(
          context,
          target == null ? RouteNames.home : RouteNames.reminder,
        );
      } else {
        ToastUtil.show(
            context, response.message.isEmpty ? '登录失败' : response.message);
      }
    } catch (error) {
      if (mounted) {
        ToastUtil.show(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadLoginPreference() async {
    try {
      final keepSignedIn = await AuthPreferences.isKeepSignedInEnabled();
      final username = await AuthPreferences.getRememberedUsername();
      if (!mounted) return;
      setState(() {
        _keepSignedIn = keepSignedIn;
        if (keepSignedIn && username != null && username.isNotEmpty) {
          _usernameController.text = username;
        }
      });
    } catch (_) {
      // Login preferences are optional; a storage read failure should not block login.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _LoginBackdrop(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight -
                        AppSpacing.md -
                        AppSpacing.lg,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _BrandMark(),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              '守护您的每一天健康',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            GlassCard(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                children: [
                                  CommonInput(
                                    label: '账号',
                                    controller: _usernameController,
                                    prefixIcon:
                                        Icons.person_outline_rounded,
                                    validator: (value) =>
                                        ValidatorUtil.required(
                                      value,
                                      message: '请输入账号',
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  CommonInput(
                                    label: '密码',
                                    controller: _passwordController,
                                    obscureText: true,
                                    prefixIcon: Icons.lock_outline_rounded,
                                    validator: ValidatorUtil.password,
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _LoginOptionRow(
                                          value: _keepSignedIn,
                                          label: '保持登录',
                                          onChanged: (value) => setState(
                                            () => _keepSignedIn = value,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => AppRouter.push(
                                          context,
                                          RouteNames.forgotPassword,
                                        ),
                                        child: const Text('忘记密码'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  LargePrimaryButton(
                                    text: '登录',
                                    loading: _loading,
                                    onPressed: _loading ? null : _submit,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      alignment: WrapAlignment.end,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const Text('还没有账号？'),
                                        TextButton(
                                          onPressed: () => AppRouter.push(
                                            context,
                                            RouteNames.register,
                                          ),
                                          child: const Text('注册账号'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _LoginOptionRow extends StatelessWidget {
  const _LoginOptionRow({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          children: [
            Checkbox(
              value: value,
              visualDensity: VisualDensity.compact,
              onChanged: (nextValue) => onChanged(nextValue ?? false),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.authService});

  final AuthService authService;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _sendingCode = false;
  bool _resetting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final usernameError = ValidatorUtil.required(
      _usernameController.text,
      message: '\u8bf7\u8f93\u5165\u8d26\u53f7',
    );
    final phoneError = ValidatorUtil.phone(_phoneController.text);
    if (usernameError != null || phoneError != null) {
      ToastUtil.show(context, usernameError ?? phoneError!);
      return;
    }
    setState(() => _sendingCode = true);
    try {
      final response = await widget.authService.sendPasswordResetCode(
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (!response.success) {
        ToastUtil.show(
          context,
          response.message.isEmpty
              ? '\u9a8c\u8bc1\u7801\u53d1\u9001\u5931\u8d25'
              : response.message,
        );
        return;
      }
      final devCode = response.data?.devCode;
      if (devCode != null && devCode.isNotEmpty) {
        _codeController.text = devCode;
      }
      ToastUtil.show(
        context,
        devCode == null || devCode.isEmpty
            ? '\u9a8c\u8bc1\u7801\u5df2\u53d1\u9001'
            : '\u9a8c\u8bc1\u7801\u5df2\u53d1\u9001\uff1a$devCode',
      );
    } catch (error) {
      if (mounted) {
        ToastUtil.show(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _sendingCode = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ToastUtil.show(
        context,
        '\u4e24\u6b21\u8f93\u5165\u7684\u5bc6\u7801\u4e0d\u4e00\u81f4',
      );
      return;
    }
    setState(() => _resetting = true);
    try {
      final response = await widget.authService.resetPassword(
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      if (!response.success) {
        ToastUtil.show(
          context,
          response.message.isEmpty
              ? '\u5bc6\u7801\u91cd\u7f6e\u5931\u8d25'
              : response.message,
        );
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              '\u5bc6\u7801\u5df2\u91cd\u7f6e\uff0c\u8bf7\u4f7f\u7528\u65b0\u5bc6\u7801\u767b\u5f55',
            ),
          ),
        );
    } catch (error) {
      if (mounted) {
        ToastUtil.show(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _resetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _sendingCode || _resetting;
    return AlertDialog(
      title: const Text('\u627e\u56de\u5bc6\u7801'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CommonInput(
                label: '\u8d26\u53f7',
                controller: _usernameController,
                prefixIcon: Icons.person_outline_rounded,
                validator: (value) => ValidatorUtil.required(
                  value,
                  message: '\u8bf7\u8f93\u5165\u8d26\u53f7',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CommonInput(
                label: '\u624b\u673a\u53f7',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_rounded,
                validator: ValidatorUtil.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CommonInput(
                      label: '\u9a8c\u8bc1\u7801',
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.verified_rounded,
                      validator: (value) => ValidatorUtil.required(
                        value,
                        message: '\u8bf7\u8f93\u5165\u9a8c\u8bc1\u7801',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: busy ? null : _sendCode,
                    child: Text(
                      _sendingCode
                          ? '\u53d1\u9001\u4e2d'
                          : '\u83b7\u53d6\u9a8c\u8bc1\u7801',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              CommonInput(
                label: '\u65b0\u5bc6\u7801',
                controller: _newPasswordController,
                obscureText: true,
                prefixIcon: Icons.lock_reset_rounded,
                validator: ValidatorUtil.password,
              ),
              const SizedBox(height: AppSpacing.md),
              CommonInput(
                label: '\u786e\u8ba4\u65b0\u5bc6\u7801',
                controller: _confirmPasswordController,
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: ValidatorUtil.password,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: const Text('\u53d6\u6d88'),
        ),
        FilledButton(
          onPressed: busy ? null : _resetPassword,
          child: Text(
            _resetting ? '\u63d0\u4ea4\u4e2d' : '\u91cd\u7f6e\u5bc6\u7801',
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      padding: EdgeInsets.zero,
      borderRadius: 30,
      colors: AppGradients.card,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFF5EA),
            AppColors.background,
            AppColors.backgroundWarm,
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
