import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
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
