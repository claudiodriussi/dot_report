import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';

import 'utils.dart';
import 'reports.dart';

void main() {
  runApp(const MyApp());
}

String currentPrinter = '';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text("Current printer is $currentPrinter"),
            ElevatedButton(
              onPressed: () async {
                final selectedAddress =
                    await FlutterBluetoothPrinter.selectDevice(context);
                if (selectedAddress != null) {
                  currentPrinter = selectedAddress.address;
                  setState(() {});
                }
              },
              child: const Text('Select printer'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentPrinter == '') {
                  noPrinter();
                } else {
                  await printerTest(context, currentPrinter);
                }
              },
              child: const Text('Printer test'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentPrinter == '') {
                  noPrinter();
                } else {
                  await basicReport(currentPrinter);
                }
              },
              child: const Text('Basic report'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentPrinter == '') {
                  noPrinter();
                } else {
                  await simpleReport(currentPrinter);
                }
              },
              child: const Text('Simple report'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentPrinter == '') {
                  noPrinter();
                } else {
                  await fixedSizeReport(currentPrinter);
                }
              },
              child: const Text('Fixed size report'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentPrinter == '') {
                  noPrinter();
                } else {
                  await mixImagesReport(currentPrinter);
                }
              },
              child: const Text('Mix report with images'),
            ),
          ],
        ),
      ),
    );
  }

  void noPrinter() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Select printer before printing'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
