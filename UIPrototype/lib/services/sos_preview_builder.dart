import 'package:intl/intl.dart';

import '../models/sos_device_model.dart';

class SosPreviewBuilder {
  const SosPreviewBuilder._();

  static String build({
    required String displayName,
    required DateTime triggeredAt,
    required SosLocationResult location,
  }) {
    final name = displayName.trim().isEmpty ? '用户' : displayName.trim();
    final time = DateFormat('yyyy-MM-dd HH:mm:ss').format(triggeredAt);
    if (!location.available) {
      return '【安康助手SOS】$name于$time发起紧急求助。'
          '当前未获取到位置，请尽快联系确认安全。';
    }
    final accuracy = location.accuracyMeters == null
        ? '精度未知'
        : '精度约${location.accuracyMeters!.round()}米';
    return '【安康助手SOS】$name于$time发起紧急求助。'
        '位置坐标（WGS84）：'
        '纬度 ${location.latitude!.toStringAsFixed(6)}，'
        '经度 ${location.longitude!.toStringAsFixed(6)}（$accuracy）。'
        '高德地图链接：${location.amapUrl}。请尽快联系确认安全。';
  }
}
