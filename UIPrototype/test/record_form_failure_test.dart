import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/health_record_model.dart';
import 'package:ankang_assistant/pages/records/record_form_page.dart';
import 'package:ankang_assistant/services/record_service.dart';
import 'package:ankang_assistant/widgets/common/common_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RejectingRecordService extends RecordService {
  int createCalls = 0;

  @override
  Future<BaseResponse<HealthRecordModel>> createRecord(
    HealthRecordModel record,
  ) async {
    createCalls++;
    return const BaseResponse(
      code: 400,
      message: '测试保存失败',
      success: false,
    );
  }
}

void main() {
  test('null response data is not parsed into a default other record', () {
    final response = BaseResponse<HealthRecordModel>.fromJson(
      {
        'code': 400,
        'message': '保存失败',
        'success': false,
        'data': null,
      },
      HealthRecordModel.fromJson,
    );

    expect(response.success, isFalse);
    expect(response.data, isNull);
  });

  testWidgets('invalid blood pressure stays on the form and is not submitted',
      (tester) async {
    final service = _RejectingRecordService();
    await _pumpForm(tester, service);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '88');
    await tester.enterText(fields.at(1), '140');
    await tester.tap(find.byType(CommonButton));
    await tester.pump();

    expect(service.createCalls, 0);
    expect(find.text('收缩压必须大于舒张压'), findsOneWidget);
    expect(find.byType(RecordFormPage), findsOneWidget);
  });

  testWidgets('rejected backend response does not create a phantom record',
      (tester) async {
    final service = _RejectingRecordService();
    await _pumpForm(tester, service);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '120');
    await tester.enterText(fields.at(1), '80');
    await tester.tap(find.byType(CommonButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(service.createCalls, 1);
    expect(find.text('测试保存失败'), findsOneWidget);
    expect(find.byType(RecordFormPage), findsOneWidget);
  });
}

Future<void> _pumpForm(
  WidgetTester tester,
  RecordService recordService,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(home: RecordFormPage(recordService: recordService)),
  );
  await tester.pumpAndSettle();
}
