import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../services/auth_service.dart';
import '../../utils/toast_util.dart';
import '../../utils/validator_util.dart';
import '../../widgets/common/common_input.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/large_primary_button.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _sendingCode = false;
  bool _resetting = false;
  String? _devCode;

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final usernameError = ValidatorUtil.required(
      _usernameController.text,
      message: '请输入账号',
    );
    final phoneError = ValidatorUtil.phone(_phoneController.text);
    if (usernameError != null || phoneError != null) {
      ToastUtil.show(context, usernameError ?? phoneError!);
      return;
    }

    setState(() => _sendingCode = true);
    try {
      final response = await _authService.sendPasswordResetCode(
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (!response.success || response.data == null) {
        ToastUtil.show(
          context,
          response.message.isEmpty ? '验证码发送失败' : response.message,
        );
        return;
      }
      _devCode = response.data!.devCode;
      if (_devCode != null && _devCode!.isNotEmpty) {
        _codeController.text = _devCode!;
        ToastUtil.show(context, '开发环境验证码：$_devCode');
      } else {
        ToastUtil.show(context, response.data!.message);
      }
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
    if (_passwordController.text != _confirmPasswordController.text) {
      ToastUtil.show(context, '两次输入的新密码不一致');
      return;
    }

    setState(() => _resetting = true);
    try {
      final response = await _authService.resetPassword(
        username: _usernameController.text.trim(),
        phone: _phoneController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );
      if (!mounted) {
        return;
      }
      if (!response.success) {
        ToastUtil.show(
          context,
          response.message.isEmpty ? '密码重置失败' : response.message,
        );
        return;
      }
      ToastUtil.show(context, '密码已重置，请使用新密码登录');
      Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('忘记密码')),
      body: DecoratedBox(
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
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text('重置登录密码', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '输入账号和绑定手机号，获取验证码后设置新密码。',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              GlassCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CommonInput(
                        label: '账号',
                        controller: _usernameController,
                        prefixIcon: Icons.person_outline_rounded,
                        validator: (value) => ValidatorUtil.required(
                          value,
                          message: '请输入账号',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CommonInput(
                        label: '手机号',
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
                              label: '验证码',
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.verified_rounded,
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return '请输入验证码';
                                }
                                return RegExp(r'^\d{6}$').hasMatch(text)
                                    ? null
                                    : '请输入 6 位验证码';
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            height: 56,
                            child: FilledButton.tonalIcon(
                              onPressed: busy ? null : _sendCode,
                              icon: _sendingCode
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sms_rounded),
                              label: const Text('获取'),
                            ),
                          ),
                        ],
                      ),
                      if (_devCode != null && _devCode!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '开发验证码：$_devCode',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      CommonInput(
                        label: '新密码',
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: Icons.lock_reset_rounded,
                        validator: ValidatorUtil.password,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CommonInput(
                        label: '确认新密码',
                        controller: _confirmPasswordController,
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                        validator: (value) {
                          final message = ValidatorUtil.password(value);
                          if (message != null) {
                            return message;
                          }
                          return value == _passwordController.text
                              ? null
                              : '两次输入的新密码不一致';
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      LargePrimaryButton(
                        text: '重置密码',
                        loading: _resetting,
                        onPressed: busy ? null : _resetPassword,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
