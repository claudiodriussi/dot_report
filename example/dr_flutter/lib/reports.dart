import 'dart:convert';
import 'package:expressions/expressions.dart';
import 'package:dot_report/dot_report.dart';
import 'package:bluetooth_thermal_printer/bluetooth_thermal_printer.dart';

import 'utils.dart';

/// This is a simple report, the result looks ugly, but it uses many of the
/// style features of dot_report.
///
Future<void> basicReport(String printer) async {
  DotReportEval rep;
  Map<String, dynamic> curRow = {};

  // connect the printer before printing
  await connectPrinter(printer);

  // onInit event callback, it is called by [init()] method, usually it is not
  // needed, the onBefore callback should be preferred.
  Future<void> _init(rep) async {
    rep.context.addAll({
      'title': rep.config['title'],
      'total': 0.0,
    });
  }

  // onBeforeBand event callback, this is called before print each band. It is
  // the right place to set context values for current row to print, the [band]
  // parameter is the name of band to be printed, so right context values can
  // be set.
  Future<void> _beforeBand(band) async {
    if (band.name == 'band') {
      band.rep.context.addAll(curRow);
    }
    if (band.name == 'logo') {
      // refresh the page counter before print a new header
      band.rep.context['page'] = band.rep.config['page'];
    }
  }

  // onAfterBand event callback, this is called right after each print band.
  // Usually is used to summarize values to be printed at the foot of report.
  Future<void> _afterBand(band) async {
    if (band.name == 'band') {
      band.rep.context['total'] +=
          band.rep.context['qt'] * band.rep.context['price'];
    }
  }

  // the instance of DotReport class or derived
  rep = DotReportEval(
    await loadScripts('test'),
    onInit: (rep) => _init(rep),
    onBeforeBand: (band) => _beforeBand(band),
    onAfterBand: (band) => _afterBand(band),
  );
  await rep.init();

  // prepare some data to print and print the band called "band". See
  // _beforeBand callback to see how to set context data.
  curRow = {
    'scu': "PRD01",
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
  await BluetoothThermalPrinter.writeBytes(rep.bytes);
}

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
