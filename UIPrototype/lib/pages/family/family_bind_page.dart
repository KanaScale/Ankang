import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../services/family_service.dart';
import '../../widgets/glass_card.dart';

class FamilyBindPage extends StatefulWidget {
  const FamilyBindPage({super.key, this.service});

  final FamilyService? service;

  @override
  State<FamilyBindPage> createState() => _FamilyBindPageState();
}

class _FamilyBindPageState extends State<FamilyBindPage> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  late final FamilyService _service;
  var _relationType = 'other';
  var _binding = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? FamilyService();
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _bind() async {
    if (!_formKey.currentState!.validate() || _binding) {
      return;
    }
    setState(() => _binding = true);
    try {
      final response = await _service.bindPatient(
        inviteCode: _inviteCodeController.text.trim(),
        relationType: _relationType,
      );
      if (!mounted) return;
      if (!response.success) {
        _showMessage(response.message.isEmpty ? '绑定失败' : response.message);
        return;
      }
      _showMessage('绑定成功');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _binding = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('绑定家人')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            GlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _inviteCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: '绑定码',
                        prefixIcon: Icon(Icons.key_rounded),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return '请输入绑定码';
                        if (text.length < 4) return '绑定码格式不正确';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<String>(
                      initialValue: _relationType,
                      decoration: const InputDecoration(
                        labelText: '关系',
                        prefixIcon: Icon(Icons.family_restroom_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'son', child: Text('儿子')),
                        DropdownMenuItem(value: 'daughter', child: Text('女儿')),
                        DropdownMenuItem(value: 'spouse', child: Text('配偶')),
                        DropdownMenuItem(value: 'parent', child: Text('父母')),
                        DropdownMenuItem(value: 'other', child: Text('其他')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _relationType = value);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _binding ? null : _bind,
                      icon: _binding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.link_rounded),
                      label: Text(_binding ? '绑定中' : '完成绑定'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
