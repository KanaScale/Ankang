import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../models/health_record_model.dart';
import '../../services/api_client.dart';
import '../../services/record_service.dart';
import '../../utils/toast_util.dart';
import '../../widgets/common/common_button.dart';
import '../../widgets/common/common_input.dart';

class RecordFormPage extends StatefulWidget {
  const RecordFormPage({
    super.key,
    this.initialType = HealthRecordType.bloodPressure,
    this.recordService,
  });

  final HealthRecordType initialType;
  final RecordService? recordService;

  @override
  State<RecordFormPage> createState() => _RecordFormPageState();
}

class _RecordFormPageState extends State<RecordFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final RecordService _recordService;
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _valueController = TextEditingController();
  final _remarkController = TextEditingController();
  late HealthRecordType _type;
  var _recordedAt = DateTime.now();
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _recordService = widget.recordService ?? RecordService();
    _type = widget.initialType;
    _systolicController.addListener(_refreshPreview);
    _diastolicController.addListener(_refreshPreview);
    _valueController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _systolicController.removeListener(_refreshPreview);
    _diastolicController.removeListener(_refreshPreview);
    _valueController.removeListener(_refreshPreview);
    _systolicController.dispose();
    _diastolicController.dispose();
    _valueController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final record = _buildRecord();
    setState(() => _saving = true);
    try {
      final response = await _recordService.createRecord(record);
      if (!mounted) {
        return;
      }
      if (!response.success || response.data == null) {
        ToastUtil.show(
          context,
          response.message.isEmpty ? '记录保存失败，请检查输入后重试' : response.message,
        );
        return;
      }
      ToastUtil.show(
          context, response.message.isEmpty ? '记录已保存' : response.message);
      Navigator.of(context).pop(response.data!);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ToastUtil.show(
        context,
        error is ApiException ? error.message : '记录保存失败，请稍后重试',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  HealthRecordModel _buildRecord() {
    final systolic = int.tryParse(_systolicController.text.trim());
    final diastolic = int.tryParse(_diastolicController.text.trim());
    final value = _type == HealthRecordType.bloodPressure
        ? (systolic ?? 0).toDouble()
        : double.tryParse(_valueController.text.trim()) ?? 0;
    return HealthRecordModel(
      id: DateTime.now().millisecondsSinceEpoch,
      type: _type,
      value: value,
      unit: _type.defaultUnit,
      systolic: systolic,
      diastolic: diastolic,
      status: HealthRecordStatusRules.evaluate(
        _type,
        value,
        systolic: systolic,
        diastolic: diastolic,
      ),
      recordedAt: _recordedAt,
      remark: _remarkController.text.trim(),
    );
  }

  Future<void> _pickRecordedAt() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDate: _recordedAt,
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_recordedAt),
    );
    if (time == null) {
      return;
    }
    setState(() {
      _recordedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('新增健康记录')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _RecordFormHero(type: _type),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<HealthRecordType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: '指标类型',
                  prefixIcon: Icon(Icons.category_rounded),
                ),
                items: const [
                  HealthRecordType.bloodPressure,
                  HealthRecordType.bloodSugar,
                  HealthRecordType.heartRate,
                  HealthRecordType.weight,
                ].map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _RangeHintCard(type: _type),
              const SizedBox(height: AppSpacing.md),
              if (_type == HealthRecordType.bloodPressure) ...[
                CommonInput(
                  label: '收缩压',
                  controller: _systolicController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.arrow_upward_rounded,
                  validator: _validateSystolic,
                ),
                const SizedBox(height: AppSpacing.md),
                CommonInput(
                  label: '舒张压',
                  controller: _diastolicController,
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.arrow_downward_rounded,
                  validator: _validateDiastolic,
                ),
              ] else
                CommonInput(
                  label: '${_type.label}数值',
                  hintText: _type.defaultUnit,
                  controller: _valueController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.monitor_heart_rounded,
                  validator: _requiredNumber,
                ),
              const SizedBox(height: AppSpacing.md),
              CommonInput(
                label: '备注',
                controller: _remarkController,
                prefixIcon: Icons.notes_rounded,
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _pickRecordedAt,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(
                  '测量时间：${_recordedAt.year}-${_recordedAt.month.toString().padLeft(2, '0')}-${_recordedAt.day.toString().padLeft(2, '0')} '
                  '${_recordedAt.hour.toString().padLeft(2, '0')}:${_recordedAt.minute.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _PreviewCard(record: _tryBuildPreview()),
              const SizedBox(height: AppSpacing.xl),
              CommonButton(
                text: '保存记录',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _requiredNumber(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || number <= 0) {
      return '请输入有效数值';
    }
    return null;
  }

  String? _validateSystolic(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 40 || number > 300) {
      return '收缩压应在 40-300 mmHg 之间';
    }
    final diastolic = int.tryParse(_diastolicController.text.trim());
    if (diastolic != null && number <= diastolic) {
      return '收缩压必须大于舒张压';
    }
    return null;
  }

  String? _validateDiastolic(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 30 || number > 200) {
      return '舒张压应在 30-200 mmHg 之间';
    }
    return null;
  }

  HealthRecordModel? _tryBuildPreview() {
    if (_type == HealthRecordType.bloodPressure) {
      final systolic = int.tryParse(_systolicController.text.trim());
      final diastolic = int.tryParse(_diastolicController.text.trim());
      if (systolic == null || diastolic == null) {
        return null;
      }
      return HealthRecordModel(
        id: 0,
        type: _type,
        value: systolic.toDouble(),
        unit: _type.defaultUnit,
        systolic: systolic,
        diastolic: diastolic,
        status: HealthRecordStatusRules.evaluate(
          _type,
          systolic.toDouble(),
          systolic: systolic,
          diastolic: diastolic,
        ),
        recordedAt: _recordedAt,
      );
    }

    final value = double.tryParse(_valueController.text.trim());
    if (value == null) {
      return null;
    }
    return HealthRecordModel(
      id: 0,
      type: _type,
      value: value,
      unit: _type.defaultUnit,
      status: HealthRecordStatusRules.evaluate(_type, value),
      recordedAt: _recordedAt,
    );
  }
}

class _RecordFormHero extends StatelessWidget {
  const _RecordFormHero({required this.type});

  final HealthRecordType type;

  @override
  Widget build(BuildContext context) {
    final color = type.accentColor;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.18),
            Colors.white,
            AppColors.greenSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(type.icon, color: color, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '记录${type.label}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  type.measureTip,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeHintCard extends StatelessWidget {
  const _RangeHintCard({required this.type});

  final HealthRecordType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: type.accentColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: type.accentColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: type.accentColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '参考范围：${type.referenceRange}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '数据仅用于日常健康管理，持续异常请及时就医。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.record});

  final HealthRecordModel? record;

  @override
  Widget build(BuildContext context) {
    final current = record;
    if (current == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '填写数值后会自动预览本次记录状态。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    final color = switch (current.status) {
      HealthRecordStatus.normal => AppColors.primary,
      HealthRecordStatus.warning => AppColors.warning,
      HealthRecordStatus.danger => AppColors.emergency,
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.16),
            foregroundColor: color,
            child: Icon(current.type.icon),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.displayValue,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text('状态：${current.status.label}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension _FormTypeStyle on HealthRecordType {
  IconData get icon => switch (this) {
        HealthRecordType.bloodPressure => Icons.water_drop_rounded,
        HealthRecordType.bloodSugar => Icons.bloodtype_rounded,
        HealthRecordType.heartRate => Icons.favorite_rounded,
        HealthRecordType.weight => Icons.monitor_weight_rounded,
        HealthRecordType.other => Icons.add_chart_rounded,
      };

  Color get accentColor => switch (this) {
        HealthRecordType.bloodPressure => AppColors.chartBlue,
        HealthRecordType.bloodSugar => AppColors.chartOrange,
        HealthRecordType.heartRate => AppColors.emergency,
        HealthRecordType.weight => AppColors.primary,
        HealthRecordType.other => AppColors.chartPurple,
      };

  String get referenceRange => switch (this) {
        HealthRecordType.bloodPressure => '收缩压 90-139，舒张压 60-89 mmHg',
        HealthRecordType.bloodSugar => '空腹血糖 3.9-6.1 mmol/L',
        HealthRecordType.heartRate => '静息心率 60-100 bpm',
        HealthRecordType.weight => '结合身高与长期趋势判断',
        HealthRecordType.other => '按实际指标记录',
      };

  String get measureTip => switch (this) {
        HealthRecordType.bloodPressure => '建议静坐 5 分钟后测量，并记录早晚数据。',
        HealthRecordType.bloodSugar => '标注空腹或餐后，有助于后续趋势判断。',
        HealthRecordType.heartRate => '运动后心率会升高，静息数据更适合长期对比。',
        HealthRecordType.weight => '建议固定在晨起空腹时记录，趋势比单次数值更重要。',
        HealthRecordType.other => '记录关键指标，帮助形成连续健康档案。',
      };
}
