import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../routes/app_router.dart';
import '../../routes/route_names.dart';
import '../../services/auth_service.dart';
import '../../utils/toast_util.dart';
import '../../utils/validator_util.dart';
import '../../widgets/common/common_input.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/large_primary_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _authService.register(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        phone: _phoneController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (response.success) {
        ToastUtil.show(context, '注册成功，请登录');
        AppRouter.replace(context, RouteNames.login);
      } else {
        ToastUtil.show(
          context,
          response.message.isEmpty ? '注册失败' : response.message,
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册账号')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
          children: [
            Text('创建健康档案', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '先完成账号创建，后续可补充健康资料。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  CommonInput(
                    label: '账号',
                    controller: _usernameController,
                    prefixIcon: Icons.person_outline_rounded,
                    maxLength: ValidatorUtil.accountMaxLength,
                    validator: ValidatorUtil.accountName,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CommonInput(
                    label: '手机号',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_outlined,
                    validator: ValidatorUtil.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CommonInput(
                    label: '密码',
                    controller: _passwordController,
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: true,
                    validator: ValidatorUtil.password,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CommonInput(
                    label: '确认密码',
                    controller: _confirmPasswordController,
                    prefixIcon: Icons.verified_user_outlined,
                    obscureText: true,
                    validator: (value) {
                      final message = ValidatorUtil.password(value);
                      if (message != null) {
                        return message;
                      }
                      return value == _passwordController.text
                          ? null
                          : '两次输入的密码不一致';
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LargePrimaryButton(
                    text: '提交注册',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  LargePrimaryButton(
                    text: '已有账号，去登录',
                    tone: LargePrimaryButtonTone.secondary,
                    onPressed: () => AppRouter.replace(
                      context,
                      RouteNames.login,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
