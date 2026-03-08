import 'package:flutter/foundation.dart';

class ZPrint {
  ZPrint(String value) {
    if (kDebugMode) {
      print(">>>> $value <<<<");
    }
  }
}
