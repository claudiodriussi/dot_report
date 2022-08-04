import 'package:flutter/material.dart';
import 'package:bluetooth_thermal_printer/bluetooth_thermal_printer.dart';

import "reports.dart";
import "utils.dart";

void main() {
  runApp(const MyApp());
}

String currentPrinter = '';

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Dot Report demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
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
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SetPrinter()),
                );
                setState(() {});
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
            )
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

/// Select printer and put address to global variable currentPrinter
///
///
class SetPrinter extends StatefulWidget {
  const SetPrinter({Key? key}) : super(key: key);
  @override
  _SetPrinter createState() => _SetPrinter();
}

class _SetPrinter extends State<SetPrinter> {
  List availableBluetoothDevices = [];

  @override
  void initState() {
    super.initState();
    getBluetooth().then((value) => setState(() {}));
  }

  Future<void> getBluetooth() async {
    List? bluetooths = await BluetoothThermalPrinter.getBluetooths;
    availableBluetoothDevices = bluetooths!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select printer"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: availableBluetoothDevices.length,
              itemBuilder: (_, index) {
                return _listItem(context, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _listItem(context, index) {
    List deviceName = availableBluetoothDevices[index].split("#");
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(width: 1, color: Colors.black38))),
      child: ListTile(
        title: GestureDetector(
          onDoubleTap: () async {
            currentPrinter = deviceName[1];
            Navigator.pop(context);
          },
          child: Text(
            deviceName[0],
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        subtitle: Text(deviceName[1]),
        trailing: IconButton(
            onPressed: () async {
              currentPrinter = deviceName[1];
              Navigator.pop(context);
            },
            icon: const Icon(Icons.send)),
      ),
    );
  }
}
