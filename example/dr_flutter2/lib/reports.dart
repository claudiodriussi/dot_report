import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:expressions/expressions.dart';
import 'package:dot_report/dot_report.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';

import 'utils.dart';
import 'main.dart';

/// This is a simple report, the result looks ugly, but it uses many of the
/// style features of dot_report.
///
Future<void> basicReport(String printer) async {
  DotReportEval rep;
  Map<String, dynamic> curRow = {};

  // onInit event callback, it is called by [init()] method, usually it is not
  // needed, the onBefore callback should be preferred.
  Future<void> init(rep) async {
    rep.context.addAll({
      'title': rep.config['title'],
      'total': 0.0,
    });
  }

  // onBeforeBand event callback, this is called before print each band. It is
  // the right place to set context values for current row to print, the [band]
  // parameter is the name of band to be printed, so right context values can
  // be set.
  Future<void> beforeBand(band) async {
    if (band.name == 'band') {
      band.rep.context.addAll(curRow);
    }
  }

  // onAfterBand event callback, this is called right after each print band.
  // Usually is used to summarize values to be printed at the foot of report.
  Future<void> afterBand(band) async {
    if (band.name == 'band') {
      band.rep.context['total'] +=
          band.rep.context['qt'] * band.rep.context['price'];
    }
  }

  // the instance of DotReport class or derived
  rep = DotReportEval(
    await loadScripts('test'),
    onInit: (rep) => init(rep),
    onBeforeBand: (band) => beforeBand(band),
    onAfterBand: (band) => afterBand(band),
  );
  await rep.init();

  // prepare some data to print and print the band called "band". See
  // _beforeBand callback to see how to set context data.
  curRow = {
    'sku': "PRD01",
    'description': "Café 01",
    'qt': 2.5,
    'price': 3.45,
  };
  await rep.print('band');

  // the method close print the footer and call the onAfter callback which can
  // be used to do cleanup.
  await rep.close();

  // the result of the report is contained in the [bytes] data member. In this
  // case bytes ar sent to bluetooth thermal printer, but you can configure
  // your output device.
  FlutterBluetoothPrinter.printBytes(
    address: currentPrinter,
    data: rep.list,
    keepConnected: false,
  );
}

// prepare some data to print
var data = [
  {'sku': "PRD01", 'description': "Café 01", 'qt': 2.5, 'price': 3.45},
  {'sku': "PRD02", 'description': "Sugar", 'qt': 3, 'price': 0},
  {'sku': "PRD03", 'description': "Robusta Coffee", 'qt': 1, 'price': 2.45},
  {'sku': "PRD04", 'description': "Arabica Coffee", 'qt': 1, 'price': 4.45},
  {'sku': "PRD05", 'description': "Blended Coffee", 'qt': 1.5, 'price': 3},
  {'sku': "PRD06", 'description': "Earl grey Tea", 'qt': 1.23, 'price': 3.5},
  {'sku': "PRD07", 'description': "English breakfast", 'qt': 2, 'price': 3.6},
  {'sku': "PRD08", 'description': "Jasmine Tea", 'qt': 1.4, 'price': 4.678},
  {'sku': "PRD09", 'description': "Gun powder Tea", 'qt': 2, 'price': 3.421},
  {'sku': "PRD10", 'description': "Oolong Tea", 'qt': 5.2, 'price': 6.32},
  {'sku': "", 'description': "Please check prices and quantity."},
  {'sku': "", 'description': ""},
];

/// this report show the most common usage of DotReport
///
Future<void> simpleReport(String printer) async {
  DotReportEval rep;
  Map<String, dynamic> curRow = {};

  Future<void> before(rep) async {
    rep.context.addAll({
      'doc_num': 123,
      'doc_date': DateTime.now(),
      'title': rep.config['title'],
      'total': 0.0,
    });
  }

  Future<void> beforeBand(band) async {
    if (band.name == 'band' || band.name == 'description') {
      band.rep.context.addAll(curRow);
    }
  }

  Future<void> afterBand(band) async {
    if (band.name == 'band') {
      band.rep.context['total'] +=
          band.rep.context['qt'] * band.rep.context['price'];
    }
  }

  // the instance of DotReport class or derived
  rep = DotReportEval(
    await loadScripts('mix'),
    onBefore: (rep) => before(rep),
    onBeforeBand: (band) => beforeBand(band),
    onAfterBand: (band) => afterBand(band),
  );

  // _beforeBand callback uses curRow to fill the context.
  for (curRow in data) {
    // note that you can choose the band to print
    if (curRow['sku'] == '') {
      await rep.print('description');
    } else {
      await rep.print('band');
    }
  }

  await rep.close();
  rep.addLines(lines: 3);

  FlutterBluetoothPrinter.printBytes(
    address: currentPrinter,
    data: rep.list,
    keepConnected: false,
  );
}

/// this report sample print 2 fixed size pages. Useful to print on dot matrix
/// printers with chemical paper.
///
Future<void> fixedSizeReport(String printer) async {
  DotReportEval rep;
  Map<String, dynamic> curRow = {};

  Future<void> brefore(rep) async {
    rep.context.addAll({
      'doc_num': 123,
      'doc_date': DateTime.now(), // note the date in DateTime format
      'title': rep.config['title'],
      'total': 0.0,
    });
  }

  Future<void> beforeBand(band) async {
    if (band.name == 'band' || band.name == 'description') {
      band.rep.context.addAll(curRow);
    }
    if (band.name == 'logo') {
      // refresh the page counter before print a new header so multi-page
      // reports can print the page number
      band.rep.context['page'] = band.rep.config['page'];
    }
  }

  Future<void> afterBand(band) async {
    if (band.name == 'band') {
      band.rep.context['total'] +=
          band.rep.context['qt'] * band.rep.context['price'];
    }
  }

  // the instance of DotReport class or derived
  rep = DotReportEval(
    await loadScripts('fixedsize'),
    onBefore: (rep) => brefore(rep),
    onBeforeBand: (band) => beforeBand(band),
    onAfterBand: (band) => afterBand(band),
  );

  // print 3 times to print more than one page
  for (int i = 0; i < 3; i++) {
    for (curRow in data) {
      if (curRow['sku'] == '') {
        await rep.print('description');
      } else {
        await rep.print('band');
      }
    }
  }

  await rep.close();
  FlutterBluetoothPrinter.printBytes(
    address: currentPrinter,
    data: rep.list,
    keepConnected: false,
  );
}

/*

/// this report mix images, barcodes and qr codes whit DotReport.
/// This don't work with fixed height forms because the system can't
/// determinate the height of images.
///
/// To print images we use the excellent https://pub.dev/packages/esc_pos_utils
/// lib which has some report capabilities, but here we use only image and
/// barcodes.
///
/// The printer can print only black or white pixels so color images are
/// converted in black and white, for better results we advice to convert
/// images to print whit dithering
///
Future<void> mixImagesReport(String printer) async {
  DotReportEval rep;
  Map<String, dynamic> curRow = {};

  // initialize the esc_pos_utils generator
  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm80, profile);

  await connectPrinter(printer);

  Future<void> _before(rep) async {
    rep.context.addAll({
      'doc_num': 123,
      'doc_date': DateTime.now(),
      'title': rep.config['title'],
      'total': 0.0,
    });
  }

  Future<void> _beforeBand(band) async {
    if (band.name == 'band' || band.name == 'description') {
      band.rep.context.addAll(curRow);
    }
    if (band.name == 'logo') {
      band.rep.context['page'] = band.rep.config['page'];
    }
  }

  Future<void> _afterBand(band) async {
    if (band.name == 'band') {
      band.rep.context['total'] +=
          band.rep.context['qt'] * band.rep.context['price'];
    }
  }

  // the instance of DotReport class or derived
  rep = DotReportEval(
    await loadScripts('mix'),
    onBefore: (rep) => _before(rep),
    onBeforeBand: (band) => _beforeBand(band),
    onAfterBand: (band) => _afterBand(band),
  );

  // start printing an image
  rep.bytes += await imageFromAssets(generator, 'assets/images/flutter.png');
  rep.bytes += resetAlignment(generator);

  curRow = data[0];
  await rep.print('band');

  // we can mix DotReport bands and barcode or qrcode
  rep.addLines();
  final List<int> barData = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 4];
  rep.bytes += generator.barcode(Barcode.upcA(barData));
  rep.bytes += resetAlignment(generator);
  rep.addLines();

  curRow = data[2];
  await rep.print('band');
  curRow = data[3];
  await rep.print('band');

  // here a qrcode
  rep.addLines();
  rep.bytes += generator.qrcode('dot_report is fun!');
  rep.bytes += resetAlignment(generator);
  rep.addLines();

  await rep.close();

  // at the end of report we print another image
  rep.bytes += await imageFromAssets(generator, 'assets/images/signature.png');
  rep.bytes += resetAlignment(generator);
  rep.addLines(lines: 3);

  await BluetoothThermalPrinter.writeBytes(rep.bytes);
}

/// load an image from assets and convert the image to list of bytes ready to
/// send to the printer.
///
Future<List<int>> imageFromAssets(Generator generator, String fileName) async {
  final ByteData data = await rootBundle.load(fileName);
  final Uint8List imgBytes = data.buffer.asUint8List();
  final img.Image image = img.decodeImage(imgBytes)!;
  return generator.image(image);
}

/// all graphic commands of esc_pos_utils lib sets the alignment to center, so
/// we restore the default alignment to left after each graphic print.
///
List<int> resetAlignment(Generator generator) =>
    generator.setStyles(PosStyles().copyWith(align: PosAlign.left));

 */

/// class derived from DotReport configured to use ExpressionEvaluator to eval
/// expressions contained within the report. It also configure the encoder
/// in ths case to [latin1] it also do some char replacer if the printer
/// doesn't support some characters.
class DotReportEval extends DotReport with ExpressionReport {
  DotReportEval(
    List<String> scripts, {
    encoder,
    onInit,
    onBefore,
    onAfter,
    onBeforeBand,
    onAfterBand,
  }) : super(
          scripts,
          encoder: encoder = latin1,
          onInit: onInit,
          onBefore: onBefore,
          onAfter: onAfter,
          onBeforeBand: onBeforeBand,
          onAfterBand: onAfterBand,
        ) {
    evaluator = evalExpression;
    // in this case the printer doesn't support italian accented vowels, so
    // I added some replacers.
    charReplacer = {
      'è': "e'",
      'à': "a'",
      'ì': "i",
      'ò': "o'",
      'ù': "u'",
      'é': "e'",
    };
  }
}

/// Configure the evaluator for [DotReportEval] class.
/// By default some useful functions are added to the context and an error
/// trapping is added in case of errors in expressions.
mixin ExpressionReport on DotReport {
  Map<String, dynamic> context = {
    'iif': iif,
    'empty': empty,
    'str': str,
  };

  ExpressionEvaluator evalIt = const ExpressionEvaluator();
  dynamic evalExpression(String str) async {
    dynamic result;
    try {
      var expression = Expression.parse(str);
      result = evalIt.eval(expression, context);
    } catch (e) {
      result = "E: $str";
    }
    return result;
  }
}

/// transform a value to string, uses toString method except for DateTime value
String str(value, {format}) {
  if (value is DateTime) {
    var fmt = DateFormat(format ?? 'MM/dd/yy');
    return fmt.format(value);
  } else {
    return value.toString();
  }
}

// this function add ternary operator to function that can be used int report
// scripts
dynamic iif(condition, valTrue, valFalse) {
  return condition ? valTrue : valFalse;
}

// this function added to context check if a value is empty depending of its
// type.
bool empty(value) {
  if (value is String) return value.trim() == '';
  if (value is num) return value == 0;
  return false;
}
