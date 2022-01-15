import 'dart:convert';
import 'dart:io';
import 'package:dot_report/dot_report.dart';
import 'package:string_eval/string_eval.dart';
import 'package:expressions/expressions.dart';

/// test dot_report with two expression evaluators.
///
/// string_eval is nice and elegant, but is hard to use in flutter, so
/// expressons is to be preferred
///
void main(List<String> arguments) async {
  // uses expression package to evaluate fields
  print(DateTime.now().millisecondsSinceEpoch);
  await testExpression();

  // add callback functions to handle events
  print(DateTime.now().millisecondsSinceEpoch);
  await testCallback();

  // uses an extended which integrate embed evaluator and data context for
  // evaluator
  print(DateTime.now().millisecondsSinceEpoch);
  await testExtended();

  // uses the string_eval evaluator
  print(DateTime.now().millisecondsSinceEpoch);
  await testEval();

  print(DateTime.now().millisecondsSinceEpoch);
}

Future<String> readFile(String fileName) async {
  File f = File(fileName);
  return await f.readAsString();
}

/// test with expression evaluator
///
Future<void> testExpression() async {
  DotReport rep;
  Map<String, dynamic> context = {};

  ExpressionEvaluator evaluator = const ExpressionEvaluator();

  dynamic evalExpression(String str) async {
    dynamic result;
    try {
      var expression = Expression.parse(str);
      result = evaluator.eval(expression, context);
    } catch (e) {
      result = "E: $str";
    }
    return result;
  }

  rep = DotReport(
    [
      await readFile('./data/test.yaml'),
      await readFile('./data/logo.yaml'),
    ],
    eval: evalExpression,
  );
  rep.charReplacer = {
    'è': "e'",
    'à': "a'",
    'ì': "i",
    'ò': "o'",
    'ù': "u'",
    'é': "e'",
  };

  context = {
    'page': rep.config['page'],
    'title': rep.config['title'],
    'scu': "PRD01",
    'description': "Caffé 01",
    'qt': 2.5,
    'price': 3.45,
    'total': 333.12,
  };

  await rep.print('band');
  await rep.close();
  print(rep.bytes.length);
}

/// test with expression evaluator and callbacks usage
///
Future<void> testCallback() async {
  DotReport rep;
  Map<String, dynamic> context = {};

  ExpressionEvaluator evaluator = const ExpressionEvaluator();

  dynamic evalExpression(String str) async {
    dynamic result;
    try {
      var expression = Expression.parse(str);
      result = evaluator.eval(expression, context);
    } catch (e) {
      result = "E: $str";
    }
    return result;
  }

  void _init(rep) {
    context = {
      'title': rep.config['title'],
      'total': 0,
    };
  }

  Map<String, dynamic> curRow = {};
  void _beforeBand(band) {
    if (band.name == 'band') {
      context.addAll(curRow);
    }
    if (band.name == 'logo') {
      // refresh the page counter before print a new header
      context['page'] = band.rep.config['page'];
    }
  }

  void _afterBand(band) {
    if (band.name == 'band') {
      context['total'] += context['qt'] * context['price'];
    }
  }

  rep = DotReport(
    [
      await readFile('./data/test.yaml'),
      await readFile('./data/logo.yaml'),
    ],
    eval: evalExpression,
    onInit: (rep) => _init(rep),
    onBeforeBand: (band) => _beforeBand(band),
    onAfterBand: (band) => _afterBand(band),
  );
  rep.charReplacer = {
    'è': "e'",
    'à': "a'",
    'ì': "i",
    'ò': "o'",
    'ù': "u'",
    'é': "e'",
  };

  curRow = {
    'scu': "PRD01",
    'description': "Café 01",
    'qt': 2.5,
    'price': 3.45,
  };
  await rep.print('band');
  await rep.close();
  print(rep.bytes.length);
}

/// test with expression evaluator, callbacks usage and derivated class
///
Future<void> testExtended() async {
  DotReportEval rep;

  void _init(rep) {
    rep.context = {
      'title': rep.config['title'],
      'total': 0,
    };
  }

  Map<String, dynamic> curRow = {};
  void _beforeBand(band) {
    if (band.name == 'band') {
      band.rep.context.addAll(curRow);
    }
    if (band.name == 'logo') {
      // refresh the page counter before print a new header
      band.rep.context['page'] = band.rep.config['page'];
    }
  }

  void _afterBand(band) {
    if (band.name == 'band') {
      band.rep.context['total'] +=
          band.rep.context['qt'] * band.rep.context['price'];
    }
  }

  rep = DotReportEval(
    [
      await readFile('./data/test.yaml'),
      await readFile('./data/logo.yaml'),
    ],
    onInit: (rep) => _init(rep),
    onBeforeBand: (band) => _beforeBand(band),
    onAfterBand: (band) => _afterBand(band),
  );

  curRow = {
    'scu': "PRD01",
    'description': "Café 01",
    'qt': 2.5,
    'price': 3.45,
  };
  await rep.print('band');
  await rep.close();
  print(rep.bytes.length);
}

mixin ExpressionReport on DotReport {
  Map<String, dynamic> context = {};

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

/// test with string_eval evaluator
///
Future<void> testEval() async {
  DotReport rep;
  Map<String, dynamic> data = {};
  StringEval evalObj = StringEval();

  Future<dynamic> evalStr(String str) async {
    dynamic result;
    try {
      result = await evalObj.calc(str);
    } catch (e) {
      result = "Err: $str";
    }
    return result;
  }

  rep = DotReport(
    [
      await readFile('./data/test.yaml'),
      await readFile('./data/logo.yaml'),
    ],
    eval: evalStr,
  );
  rep.charReplacer = {
    'è': "e'",
    'à': "a'",
    'ì': "i",
    'ò': "o'",
    'ù': "u'",
    'é': "e'",
  };

  data = {
    'page': rep.config['page'],
    'title': rep.config['title'],
    'scu': "PRD01",
    'description': "Caffé 01",
    'qt': 2.5,
    'price': 3.45,
    'total': 333.12,
  };
  evalObj.buildVars(data);

  await rep.print('band');
  await rep.close();
  print(rep.bytes.length);
}
