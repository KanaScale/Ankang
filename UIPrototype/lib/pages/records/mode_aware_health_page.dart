import 'package:flutter/material.dart';

import '../../services/care_mode_service.dart';
import '../family/family_health_page.dart';
import 'record_list_page.dart';

class ModeAwareHealthPage extends StatelessWidget {
  const ModeAwareHealthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CareMode>(
      valueListenable: CareModeService.mode,
      builder: (context, mode, _) {
        if (mode == CareMode.caregiver) {
          return const FamilyHealthPage();
        }
        return const RecordListPage();
      },
    );
  }
}
