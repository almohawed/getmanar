import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceContextInfo {
  final String platform;
  final String browser;
  final String userAgent;
  final String device;

  const DeviceContextInfo({
    required this.platform,
    required this.browser,
    required this.userAgent,
    required this.device,
  });

  static Future<DeviceContextInfo> collect() async {
    final plugin = DeviceInfoPlugin();
    if (kIsWeb) {
      final info = await plugin.webBrowserInfo;
      return DeviceContextInfo(
        platform: 'web',
        browser: info.browserName.name,
        userAgent: (info.userAgent ?? '').toString(),
        device: 'web',
      );
    }

    return DeviceContextInfo(
      platform: defaultTargetPlatform.name,
      browser: '',
      userAgent: '',
      device: defaultTargetPlatform.name,
    );
  }
}

