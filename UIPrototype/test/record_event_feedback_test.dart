import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/health_event_model.dart';
import 'package:ankang_assistant/models/health_record_model.dart';
import 'package:ankang_assistant/pages/records/record_form_page.dart';
import 'package:ankang_assistant/pages/records/record_list_page.dart';
import 'package:ankang_assistant/pages/records/trend_page.dart';
import 'package:ankang_assistant/services/care_mode_service.dart';
import 'package:ankang_assistant/services/health_event_service.dart';
import 'package:ankang_assistant/services/record_service.dart';
import 'package:ankang_assistant/widgets/common/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRecordService extends RecordService {
  bool createCalled = false;

  @override
  Future<BaseResponse<PageResult<HealthRecordModel>>> getRecords({
    int page = 1,
    int pageSize = 20,
    HealthRecordType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return const BaseResponse<PageResult<HealthRecordModel>>(
      code: 200,
      message: '查询成功',
      success: true,
      data: PageResult<HealthRecordModel>(
        items: [],
        total: 0,
        page: 1,
        pageSize: 20,
      ),
    );
  }

  @override
  Future<BaseResponse<HealthRecordModel>> createRecord(
    HealthRecordModel record,
  ) async {
    createCalled = true;
    return BaseResponse<HealthRecordModel>(
      code: 200,
      message: '保存成功',
      success: true,
      data: HealthRecordModel(
        id: 88,
        type: record.type,
        value: record.value,
        systolic: record.systolic,
        diastolic: record.diastolic,
        unit: record.unit,
        recordedAt: record.recordedAt,
        status: HealthRecordStatus.danger,
      ),
    );
  }
}

class _FakeHealthEventService extends HealthEventService {
  @override
  Future<HealthEventModel?> waitForRecordEvent(
    int healthRecordId, {
    Duration timeout = const Duration(seconds: 8),
    Duration interval = const Duration(milliseconds: 400),
  }) async {
    return HealthEventModel.fromJson({
      'eventId': 'event-88',
      'healthRecordId': healthRecordId,
      'status': 'completed',
      'riskLevel': 'high',
      'riskScore': 85,
      'summary': '检测到较高健康风险',
      'reasons': ['血压明显偏高'],
    });
  }
}

void main() {
  testWidgets('record save automatically shows Event Mesh risk feedback',
      (tester) async {
    final recordService = _FakeRecordService();
    await CareModeService.selectMode(CareMode.patient);
    addTearDown(CareModeService.clearRuntime);
    await tester.binding.setSurfaceSize(const Size(900, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: RecordListPage(
          recordService: recordService,
          healthEventService: _FakeHealthEventService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新增记录'));
    await tester.pumpAndSettle();
    expect(find.byType(RecordFormPage), findsOneWidget);

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), '168');
    await tester.enterText(fields.at(1), '108');
    await tester.tap(find.byType(CommonButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(recordService.createCalled, isTrue);
    expect(find.byType(RecordFormPage), findsNothing);
    expect(find.text('检测到较高健康风险'), findsWidgets);
    expect(find.text('血压明显偏高'), findsOneWidget);
    expect(find.text('进入 SOS'), findsOneWidget);
    expect(find.text('咨询 Agent'), findsNothing);

    await tester.tap(find.text('查看趋势'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TrendPage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(RecordListPage), findsOneWidget);
    expect(find.byType(RecordFormPage), findsNothing);
    expect(find.textContaining('168'), findsWidgets);
  });
}
