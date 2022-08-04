import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'package:bluetooth_thermal_printer/bluetooth_thermal_printer.dart';

/// as parameter of DotReport you must pass a list of yaml scripts. In this
/// case scripts are stored in assets, and the main script contains the list
/// of sub-scripts required.
///
/// This function load the main script from assets, then load from yaml file
/// the list of sub-scripts and finally load all the scripts.
///
Future<List<String>> loadScripts(String script) async {
  List<String> scripts = [];

  Future<String> _loadScript(String key) async {
    return await rootBundle.loadString('assets/dot_report/$key.yaml');
  }

  var mainScript = await _loadScript(script);
  scripts.add(mainScript);
  dynamic doc = loadYaml(mainScript);
  var ll = doc['config']['scripts'] ?? [];
  for (doc in ll) {
    dynamic txt = await _loadScript(doc);
    scripts.add(txt);
  }
  return scripts;
}

/// test if printer works.
///
Future<void> printerTest(context, String printer) async {
  if (!await connectPrinter(printer)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Printer not connected!'),
        duration: Duration(seconds: 2),
      ),
    );
    return;
  }
  String result = "Printer Ok!\n\n\n\n\n\n";
  await BluetoothThermalPrinter.writeBytes(result.codeUnits);
}

/// connect the printer
///
Future<bool> connectPrinter(String printer) async {
  String? result = await BluetoothThermalPrinter.connectionStatus;
  if (result != 'true') {
    result = await BluetoothThermalPrinter.connect(printer);
  }
  if (result != 'true') {
    return false;
  }
  return true;
}
