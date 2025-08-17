import 'package:flutter/services.dart';
import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

class PhoneCallHelper {
  static const MethodChannel _channel = MethodChannel('phone_call_helper');

  static Future<bool> makePhoneCall(String phoneNumber) async {
    try {
      if (Platform.isAndroid) {
        final bool result = await _channel.invokeMethod('makeCall', {
          'phoneNumber': phoneNumber,
        });
        return result;
      } else {
        // For iOS, try url_launcher
        final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
        return await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Error making phone call: $e');
      return false;
    }
  }
}
