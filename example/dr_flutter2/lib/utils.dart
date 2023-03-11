import 'dart:typed_data';
// import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';

import 'main.dart';

/// test if printer works.
///
Future<void> printerTest(context, String printer) async {
  String result = "Printer Ok!\n\n\n\n\n\n";
  FlutterBluetoothPrinter.printBytes(
      address: currentPrinter,
      data: Uint8List.fromList(result.codeUnits),
      keepConnected: false);
}
