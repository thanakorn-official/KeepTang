import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ThaiSlipOcr {
  ThaiSlipOcr._();

  static const _channel = MethodChannel('keeptang/slip_ocr');

  /// Reads Thai and English locally on supported Android builds.
  static Future<List<String>?> recognize(String imagePath) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeListMethod<String>('recognizeThai', {
        'path': imagePath
      }).timeout(const Duration(seconds: 15), onTimeout: () => null);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
