import 'dart:math';
import 'dart:convert';
import 'package:yaml/yaml.dart';

class DotReport {
  // the buffer for data to be sent to the printer
  List<int> bytes = [];

  // configuration parameters from yaml file
  Map<String, dynamic> config = {};

  // bands for thsi script
  Map<String, Band> bands = {};

  // useless evaluator. Each field to be printed must be evaluated in some way
  // by default the content of field is simpe copied to the buffer but in real
  // cases some evalation is required.
  dynamic evaluator = (String str) => str;

  // the encoder used to transalte strings. The init command can send differnt
  // configuration commands for differnt encoders.
  Encoding encoder;

  // some special characters can be not recognized by encoder so can be replaced.
  Map<String, String> charReplacer = {};

  // end of row sequence, usually '\n'
  String endOfRow = '\n';

  // The command dialect in use.
  Commands cmd = EscPos();

  DotReport(
    String script, {
    var eval,
    this.encoder = latin1,
    addScripts = const [],
  }) {
    if (eval != null) {
      evaluator = eval;
    }
    bytes = [];

    var doc = loadYaml(script);

    // configuration fields
    config['name'] = doc['config']['name'] ?? '';
    config['description'] = doc['config']['description'] ?? '';
    config['title'] = doc['config']['title'] ?? '';
    // zero mean roll print without page break
    config['page_length'] = doc['config']['page_length'] ?? 0;
    // the band to print before all headers
    config['logo'] = doc['config']['logo'] ?? 'logo';
    // the fires header and headers from second page
    config['header'] = doc['config']['header'] ?? ['header', 'header'];
    // the last footer and footers before last page
    config['footer'] = doc['config']['footer'] ?? ['footer', 'footer'];
    // escape characters to indeftify fields in image band
    config['escape'] = doc['config']['escape'] ?? '\\~';
    // accepted placeholder characters within fields
    config['placeholder'] = doc['config']['placeholder'] ?? 'x.@';
    // empty rows to add after the end of report
    config['cut_rows'] = doc['config']['cut_rows'] ?? 0;
    // current page
    config['page'] = 1;

    // bands from extraScripts are hided by main script
    addScripts.forEach((script) {
      var doc = loadYaml(script);
      doc['bands'].forEach((k, v) {
        bands[k] = Band(this, k, v);
      });
    });

    // bulid bands
    doc['bands'].forEach((k, v) {
      bands[k] = Band(this, k, v);
    });

    // check default bands
    if (config['header'].length < 2) config['header'].add(config['header'][0]);
    if (config['footer'].length < 2) config['footer'].add(config['footer'][0]);
    void chkBands(List list) {
      for (var v in list) {
        if (!bands.containsKey(v)) {
          bands[v] = Band(this, v, {});
        }
      }
    }

    chkBands([config['logo']]);
    chkBands(config['header']);
    chkBands(config['footer']);
    // find rows to print before page break
    if (config['page_length'] != 0) {
      bodyRows = config['page_length'] -
          max(
            bands[config['footer'][0]]!.rows,
            bands[config['footer'][1]]!.rows,
          );
    }
    onInit();
  }

  /// replace characters not recognized by encoder
  ///
  String charReplace(String s) {
    for (String from in charReplacer.keys) {
      s = s.replaceAll(from, charReplacer[from] ?? from);
    }
    return s;
  }

  bool start = false;
  int curRow = 0;
  int bodyRows = 0;

  Future<void> print(band) async {
    Band b = bands[band]!;
    // print first header
    if (!start) {
      onBefore();
      bytes.addAll(encoder.encode(cmd.init[0]));
      start = true;
      await print(config['logo']);
      await print(config['header'][0]);
    }
    // if not roll print calculate page break and print foter and header
    if (config['page_length'] != 0) {
      if (curRow + b.rows > bodyRows) {
        while (curRow < bodyRows) {
          bytes.addAll(encoder.encode(endOfRow));
          curRow += 1;
        }
        await print(config['footer'][1]);
        config['page'] += 1;
        curRow = 0;
        await print(config['logo']);
        await print(config['header'][1]);
      }
    }
//    onBeforeBand(band);
    bytes.addAll(await b.print());
    curRow += b.rows;
//    onAfterBand(band);
  }

  Future<void> close() async {
    Band b = bands[config['footer'][0]]!;
    if (!start) return;
    while (curRow < bodyRows) {
      bytes.addAll(encoder.encode(endOfRow));
      curRow += 1;
    }
    bytes.addAll(await b.print());
    bytes.addAll(encoder.encode(endOfRow * config['cut_rows']));
    onAfter();
  }

  void onInit() {}
  void onBefore() {}
  void onAfter() {}
  void onBeforeBand(String band) {}
  void onAfterBand(String band) {}
}

class Band {
  DotReport rep;
  String name;
  String image = "";
  var values = [];
  List pos = [];
  int rows = 0;

  Band(this.rep, this.name, Map v) {
    if (v.containsKey('image')) {
      image = v['image'].trimRight() + rep.endOfRow;
      values = v['values'];
      calcPos();
      rows = image.split('\n').length - 1;
    }
  }

  /// calc pos of fields in reversed order
  ///
  /// each element is a list with 0= index of value, 1=pos, 2=lenght
  ///
  calcPos() {
    bool inFiled = false;
    int start = 0;
    int len = 0;
    for (int i = 0; i < image.length; i++) {
      bool change = false;
      String s = rep.config['escape'];
      void endField() {
        len = i - start;
        pos.add([pos.length, start, len]);
      }

      if (inFiled && !rep.config['placeholder'].contains(image[i])) {
        endField();
        inFiled = !inFiled;
      }
      if (inFiled) s += ' \n';
      change = s.contains(image[i]);
      if (change) {
        if (inFiled) {
          endField();
        } else {
          start = i;
        }
        inFiled = !inFiled;
      }
    }
    pos = List.from(pos.reversed);
  }

  /// print a single band
  ///
  ///
  Future<List<int>> print() async {
    List<int> bytes = [];
    String result = image;

    rep.onBeforeBand(name);
    String checkStrings(String s1, String s2, {defChar = ''}) {
      for (int i = 0; i < s1.length; i++) {
        if (s2.contains(s1[i])) return s1[i];
      }
      return defChar;
    }

    for (int i = 0; i < pos.length; i++) {
      // evaluate the value
      var commands = values[pos[i][0]][0];
      var script = values[pos[i][0]][1];
      int lenFld = pos[i][2];
      // check for double whdth fields
      if (checkStrings(commands, 'DW', defChar: '') != '') lenFld = lenFld ~/ 2;

      // transform the value to string
      dynamic t = await rep.evaluator(script);
      String fld = '';
      if (t is String) {
        fld = rep.charReplace(t);
      } else if (t is num) {
        if (t == 0 && commands.indexOf('S') != -1) {
          fld = '';
        } else {
          var cmd = checkStrings(commands, '0123456789', defChar: '2');
          fld = t.toStringAsFixed(int.parse(cmd));
        }
        // string too big it is an error.
        if (fld.length > lenFld) fld = '*' * lenFld;
      } else {
        fld = t.toString();
      }

      // set the lenght of string and alignment
      t = checkStrings(commands, 'LR', defChar: t is num ? 'R' : 'L');
      if (fld.length > lenFld) {
        fld = fld.substring(0, lenFld);
      } else if (t == 'R') {
        fld = fld.padLeft(lenFld);
      } else {
        fld = fld.padRight(lenFld);
      }

      // apply printer commands
      if (commands.contains('B')) {
        fld = rep.cmd.bold[0] + fld + rep.cmd.bold[1];
      }
      if (commands.contains('U')) {
        fld = rep.cmd.underline[0] + fld + rep.cmd.underline[1];
      }
      if (commands.contains('u')) {
        fld = rep.cmd.underline2[0] + fld + rep.cmd.underline2[1];
      }
      if (commands.contains('D')) {
        fld = rep.cmd.doubleSize[0] + fld + rep.cmd.doubleSize[1];
      }
      if (commands.contains('W')) {
        fld = rep.cmd.doubleWidth[0] + fld + rep.cmd.doubleWidth[1];
      }
      if (commands.contains('H')) {
        fld = rep.cmd.doubleHeight[0] + fld + rep.cmd.doubleHeight[1];
      }
      if (commands.contains('E')) {
        fld = rep.cmd.reverse[0] + fld + rep.cmd.reverse[1];
      }

      // replace string
      var left = result.substring(0, pos[i][1]);
      var rigth = result.substring(pos[i][1] + pos[i][2]);
      result = left + fld + rigth;
    }
    // result = result.replaceAll('\r\n', '\n');
    // result = result.replaceAll('\n', '\r\n');
    result = rep.charReplace(result);
    if (result.endsWith(rep.endOfRow + '|' + rep.endOfRow)) {
      result = result.substring(0, result.length - ('|' + rep.endOfRow).length);
    }
    bytes.addAll(rep.encoder.encode(result));
    rep.onAfterBand(name);
    return bytes;
  }
}

/* recognized commands
B Bold
U Underline
u Underline2
D Double size
W Double width
H Double height
E Reverse mode

0-9 N. of decimals
S Space if zero

L left alignment
R Right alignment
 */

const ESC = '\x1b'; // 27
const FS = '\x1c'; // 28
const GS = '\x1d'; // 29

/// generic abstract commands class.
///
/// The derivated classes implements commands that can be sent to the printer
///
class Commands {
  List init = [];
  List bold = [];
  List underline = [];
  List underline2 = [];
  List reverse = [];
  List doubleSize = [];
  List doubleWidth = [];
  List doubleHeight = [];
}

/// Commands for the ESC/POS dialect
///
class EscPos extends Commands {
  @override
  List init = ["$ESC@", ""];
  @override
  List bold = ["${ESC}E\x01", "${ESC}E\x00"];
  @override
  List underline = ["$ESC-\x01", "$ESC-\x00"];
  @override
  List underline2 = ["$ESC-\x02", "$ESC-\x00"];
  @override
  List reverse = ["${GS}B\x01", "${GS}B\x00"];
  @override
  List doubleSize = ["$ESC!\x30", "$ESC!\x00"];
  @override
  List doubleWidth = ["$ESC!\x20", "$ESC!\x00"];
  @override
  List doubleHeight = ["$ESC!\x10", "$ESC!\x00"];
}
