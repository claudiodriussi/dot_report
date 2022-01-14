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
  print(DateTime.now().millisecondsSinceEpoch);
  await testEval();
  print(DateTime.now().millisecondsSinceEpoch);
  await testExpression();
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
  print(rep.bytes);
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
  print(rep.bytes);
}
