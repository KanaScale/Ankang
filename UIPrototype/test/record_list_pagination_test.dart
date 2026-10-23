import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/health_record_model.dart';
import 'package:ankang_assistant/pages/records/record_list_page.dart';
import 'package:ankang_assistant/services/record_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PagedRecordService extends RecordService {
  final requestedPages = <int>[];
  final requestedPageSizes = <int>[];

  late final records = List.generate(
    25,
    (index) => HealthRecordModel(
      id: index + 1,
      type: HealthRecordType.bloodPressure,
      value: (120 + index).toDouble(),
      systolic: 120 + index,
      diastolic: 80,
      unit: 'mmHg',
      status: HealthRecordStatus.normal,
      recordedAt: DateTime(2026, 7, 27).subtract(Duration(days: index)),
    ),
  );

  @override
  Future<BaseResponse<PageResult<HealthRecordModel>>> getRecords({
    int page = 1,
    int pageSize = 20,
    HealthRecordType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    requestedPages.add(page);
    requestedPageSizes.add(pageSize);
    final start = (page - 1) * pageSize;
    final items = start >= records.length
        ? const <HealthRecordModel>[]
        : records.sublist(start, (start + pageSize).clamp(0, records.length));
    return BaseResponse(
      code: 200,
      message: '查询成功',
      success: true,
      data: PageResult(
        items: items,
        total: records.length,
        page: page,
        pageSize: pageSize,
      ),
    );
  }
}

void main() {
  testWidgets('overview shows recent records and history loads all pages',
      (tester) async {
    final service = _PagedRecordService();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: RecordListPage(recordService: service)),
    );
    await tester.pumpAndSettle();

    expect(service.requestedPages, [1]);
    expect(service.requestedPageSizes, [10]);
    expect(find.text('120/80 mmHg'), findsWidgets);
    expect(find.text('123/80 mmHg'), findsNothing);
    expect(find.byKey(const ValueKey('patient_add_record')), findsOneWidget);
    expect(find.text('新增数据'), findsOneWidget);
    expect(
      tester.getCenter(find.text('趋势')).dx,
      lessThan(tester.getCenter(find.text('新增数据')).dx),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).floatingActionButton,
      isNull,
    );

    expect(
      find.byKey(const ValueKey('patient_view_all_records')),
      findsOneWidget,
    );
    expect(
      tester.widget(
        find.byKey(const ValueKey('patient_view_all_records')),
      ),
      isA<TextButton>(),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('patient_view_all_records')),
    );
    await tester.tap(
      find.byKey(const ValueKey('patient_view_all_records')),
    );
    await tester.pumpAndSettle();

    expect(service.requestedPages, [1, 1]);
    expect(service.requestedPageSizes, [10, 20]);

    await tester.drag(find.byType(ListView).last, const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(service.requestedPages, [1, 1, 2]);
    expect(service.requestedPageSizes, [10, 20, 20]);
  });

  testWidgets('100 percent text uses large text layout',
      (tester) async {
    final service = _PagedRecordService();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1),
          ),
          child: child!,
        ),
        home: RecordListPage(recordService: service),
      ),
    );
    await tester.pumpAndSettle();

    const recordId = 1;
    final status = find.byKey(const ValueKey('record_status_$recordId'));
    final title = find.byKey(const ValueKey('record_title_$recordId'));
    final value = find.byKey(const ValueKey('record_value_$recordId'));
    final delete = find.byKey(const ValueKey('record_delete_$recordId'));

    expect(status, findsOneWidget);
    expect(title, findsOneWidget);
    expect(value, findsOneWidget);
    expect(delete, findsOneWidget);
    expect(
      tester.getBottomLeft(status).dy,
      lessThan(tester.getTopLeft(value).dy),
    );
    expect(
      (tester.getCenter(status).dx - tester.getCenter(value).dx).abs(),
      lessThan(1),
    );
    expect(
      (tester.getCenter(title).dy - tester.getCenter(status).dy).abs(),
      lessThan(12),
    );
    expect(
      (tester.getCenter(value).dy - tester.getCenter(delete).dy).abs(),
      lessThan(12),
    );
  });
}
