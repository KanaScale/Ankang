import 'package:ankang_assistant/models/base_response.dart';
import 'package:ankang_assistant/models/family_models.dart';
import 'package:ankang_assistant/pages/family/family_home_page.dart';
import 'package:ankang_assistant/services/care_mode_service.dart';
import 'package:ankang_assistant/services/family_service.dart';
import 'package:ankang_assistant/widgets/ios_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFamilyService extends FamilyService {
  int patientLoads = 0;

  @override
  Future<BaseResponse<List<BoundPatientModel>>> getBoundPatients() async {
    patientLoads++;
    return const BaseResponse<List<BoundPatientModel>>(
      code: 200,
      message: 'success',
      success: true,
      data: [],
    );
  }
}

Widget _testApp({
  required FamilyService service,
  bool settingsPage = true,
  double textScale = 1,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
      ),
      child: settingsPage
          ? FamilyCareSettingsPage(service: service)
          : FamilyHomePage(service: service),
    ),
  );
}

void main() {
  tearDown(CareModeService.clearRuntime);

  testWidgets('病人版只显示生成绑定码操作', (tester) async {
    CareModeService.mode.value = CareMode.patient;
    final service = _FakeFamilyService();

    await tester.pumpWidget(_testApp(service: service));
    await tester.pump();

    expect(find.text('生成家庭照护绑定码'), findsOneWidget);
    expect(find.text('生成绑定码'), findsOneWidget);
    expect(find.text('输入绑定码'), findsNothing);
    expect(find.text('我照护的家人'), findsNothing);
    expect(service.patientLoads, 0);
  });

  testWidgets('家属版只显示输入绑定码和被照护者列表', (tester) async {
    CareModeService.mode.value = CareMode.caregiver;
    final service = _FakeFamilyService();

    await tester.pumpWidget(_testApp(service: service));
    await tester.pumpAndSettle();

    expect(find.text('绑定被照护者'), findsOneWidget);
    expect(find.text('输入绑定码'), findsWidgets);
    expect(find.text('已绑定关系'), findsOneWidget);
    expect(find.text('生成绑定码'), findsNothing);
    expect(find.text('生成家庭照护绑定码'), findsNothing);
    expect(service.patientLoads, 1);
  });

  testWidgets('我的子页面不显示家庭照护底栏', (tester) async {
    CareModeService.mode.value = CareMode.patient;

    await tester.pumpWidget(_testApp(service: _FakeFamilyService()));

    expect(find.byType(IosBottomNavigation), findsNothing);
  });

  testWidgets('家属照护根页面显示照护底栏', (tester) async {
    CareModeService.mode.value = CareMode.caregiver;

    await tester.pumpWidget(
      _testApp(service: _FakeFamilyService(), settingsPage: false),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IosBottomNavigation), findsOneWidget);
    expect(find.byKey(const ValueKey('care_mode_patient_button')), findsNothing);
    expect(find.text('输入绑定码'), findsNothing);
  });

  testWidgets('大字号下版本按钮改为纵向排列', (tester) async {
    CareModeService.mode.value = CareMode.patient;

    await tester.pumpWidget(
      _testApp(service: _FakeFamilyService(), textScale: 1.3),
    );

    final patient = tester.getRect(
      find.byKey(const ValueKey('care_mode_patient_button')),
    );
    final caregiver = tester.getRect(
      find.byKey(const ValueKey('care_mode_caregiver_button')),
    );
    expect(caregiver.top, greaterThan(patient.bottom));
  });
}
