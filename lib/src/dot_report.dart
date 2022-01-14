import 'dart:math';
import 'dart:convert';
import 'package:yaml/yaml.dart';

/// A text based reporting system
///
/// The constructor accept strings in yaml format which contains configuration
/// parameters, text images and field values with style directives.
///
/// Once the system is initialized, with the [print] method the bands declared
/// in scripts are written into the print buffer and the [close] method send
/// the last data.
///
/// The result is a list of bytes which can be sent to real printers.
///
class DotReport {
  // the buffer for data to be sent to the printer
  List<int> bytes = [];

  // configuration parameters from yaml file
  Map<String, dynamic> config = {};

  // bands for thsi script
  Map<String, _Band> bands = {};

  // useless evaluator. Each field to be printed must be evaluated in some way
  // by default the content of field is simpe copied to the buffer but in real
  // cases some evalation is required.
  // ignore: prefer_function_declarations_over_variables
  dynamic evaluator = (String str) => str;

  // the encoder used to transalte strings. The init command should send
  // differnt configuration commands for differnt encoders.
  Encoding encoder;

  // some special characters can be not recognized by encoder so we can set
  // a replacer
  Map<String, String> charReplacer = {};

  // end of row sequence, usually '\n'
  String endOfRow = '\n';

  // The command dialect in use.
  Commands cmd = EscPos();

  /// The report constructor
  ///
  /// Accept a list of [scripts] which are texts in yaml format wich contains
  /// configuration parameters and bands. Confiugration parameters are in the
  /// first script and the bands can be in every script, so you can reuse bands
  /// in different reports. If same band is in more than one scritpt the
  /// precedence is given to the prior which hide the following.
  ///
  /// The required [eval] parameter is a function which accept the expressions
  /// present in bands and return the evaluated result.
  ///
  /// The optional parameter [encoder] define the encoder used to transform
  /// strings to bytes for printers, by default latin1 is used.
  ///
  DotReport(
    List<String> scripts, {
    required Function eval,
    this.encoder = latin1,
  }) {
    evaluator = eval;
    bytes = [];

    // the first script contain the configuration parameters
    var doc = loadYaml(scripts[0]);
    // configuration fields
    // name of script
    config['name'] = doc['config']['name'] ?? '';
    // a short description
    config['description'] = doc['config']['description'] ?? '';
    // title of report
    config['title'] = doc['config']['title'] ?? '';
    // page lenght for page prenters, zero mean roll print without page break
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
    config['placeholders'] = doc['config']['placeholders'] ?? 'x.@';
    // empty rows to add after the end of report
    config['cut_rows'] = doc['config']['cut_rows'] ?? 0;
    // current page
    config['page'] = 1;

    // load bands from scripts in reverse order so bands in later scripts are
    // hided by preceding scripts
    for (var script in scripts.reversed) {
      var doc = loadYaml(script);
      doc['bands'].forEach((k, v) {
        bands[k] = _Band(this, k, v);
      });
    }

    // check default required bands. if not present, empty bands are added
    void chkBands(List list) {
      for (var v in list) {
        if (!bands.containsKey(v)) {
          bands[v] = _Band(this, v, {});
        }
      }
    }

    if (config['header'].length < 2) config['header'].add(config['header'][0]);
    if (config['footer'].length < 2) config['footer'].add(config['footer'][0]);
    chkBands([config['logo']]);
    chkBands(config['header']);
    chkBands(config['footer']);

    // determinate the greather (in rows) between foters to find rows to print
    // before page break
    if (config['page_length'] != 0) {
      bodyRows = config['page_length'] -
          max(
            bands[config['footer'][0]]!.rows,
            bands[config['footer'][1]]!.rows,
          );
    }

    // let's start, do some initializations
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

  // runtime variables
  bool start = false;
  int curRow = 0;
  int bodyRows = 0;

  /// Print a band
  ///
  /// the [band] parameter is the name of band to be printed and it must be
  /// presente in the bands Map.
  ///
  /// This method automatically handle the pagebreak condition and print all
  /// default bands which are "logo", "headers" and "footers" the result of
  /// the band evaluation is stored in bytes buffer.
  ///
  Future<void> print(String band) async {
    _Band b = bands[band]!;

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

    // evaluate and print the band
    bytes.addAll(await b.print());
    curRow += b.rows;
  }

  /// close the report.
  ///
  /// Print the last "footer" band and return the buffer to be sent to printer
  ///
  Future<List<int>> close() async {
    _Band b = bands[config['footer'][0]]!;
    if (!start) return bytes;
    while (curRow < bodyRows) {
      bytes.addAll(encoder.encode(endOfRow));
      curRow += 1;
    }
    bytes.addAll(await b.print());
    bytes.addAll(encoder.encode(endOfRow * config['cut_rows']));
    onAfter();
    return bytes;
  }

  // some events methods

  void onInit() {}
  void onBefore() {}
  void onAfter() {}
  void onBeforeBand(String band) {}
  void onAfterBand(String band) {}
}

/// support class for DotReport
///
/// handle band text images, evaluate fields, apply commands and do the image
/// substiutions
class _Band {
  DotReport rep;
  String name;
  String image = "";
  var values = [];
  List pos = [];
  int rows = 0;

  /// parameters are the reference to the report, the name and the Map of band
  /// image and values.
  ///
  /// Do the calculations needed to print the band.
  ///
  _Band(this.rep, this.name, Map v) {
    if (v.containsKey('image')) {
      image = v['image'].trimRight() + rep.endOfRow;
      values = v['values'];
      _calcPos();
      rows = image.split('\n').length - 1;
    }
  }

  /// calc pos of fields in reversed order so values exceding the image fields
  /// are ignored.
  ///
  /// each element of the pos list is a list with:
  /// 0= index of value, 1=pos, 2=lenght
  ///
  _calcPos() {
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

      if (inFiled && !rep.config['placeholders'].contains(image[i])) {
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
  /// the image fields are replaced with values evaluated. Then the printer
  /// commands are applied to every field. the list of bytes whith the
  /// evaluated image is returned
  ///
  /// recognized commands are:
  /// B Bold
  /// U Underline
  /// u Underline2
  /// D Double size
  /// W Double width
  /// H Double height
  /// E Reverse mode

  /// 0-9 N. of decimals
  /// S Space if zero

  /// L left alignment
  /// R Right alignment
  ///
  Future<List<int>> print() async {
    List<int> bytes = [];
    String result = image;

    rep.onBeforeBand(name);
    // utility function to find a command in list of commands.
    String checkStrings(String s1, String s2, {defChar = ''}) {
      for (int i = 0; i < s1.length; i++) {
        if (s2.contains(s1[i])) return s1[i];
      }
      return defChar;
    }

    // evaluate fields in reverse order so absolute positions in image are
    // preserved
    for (int i = 0; i < pos.length; i++) {
      // evaluate the value
      var commands = values[pos[i][0]][0];
      var script = values[pos[i][0]][1];
      int lenFld = pos[i][2];

      // check for double whdth fields
      if (checkStrings(commands, 'DW') != '') lenFld = lenFld ~/ 2;

      // evaluate the field and transform the value to string
      dynamic t = await rep.evaluator(script);
      String fld = '';
      if (t is String) {
        fld = rep.charReplace(t);
      } else if (t is num) {
        // if value is a number it is transformed in number in commands can
        // be declared the numbero of decimals.
        if (t == 0 && commands.indexOf('S') != -1) {
          fld = '';
        } else {
          var cmd = checkStrings(commands, '0123456789');
          if (cmd == '') {
            fld = t.toString();
          } else {
            fld = t.toStringAsFixed(int.parse(cmd));
          }
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

      // replace fields into image whith resulting string
      var left = result.substring(0, pos[i][1]);
      var rigth = result.substring(pos[i][1] + pos[i][2]);
      result = left + fld + rigth;
    }
    // if band ends with a pipe char it is removed because it is a placeholder
    // to handle text images in yaml files
    if (result.endsWith(rep.endOfRow + '|' + rep.endOfRow)) {
      result = result.substring(0, result.length - ('|' + rep.endOfRow).length);
    }
    // encode result and return bytes
    bytes.addAll(rep.encoder.encode(result));
    rep.onAfterBand(name);
    return bytes;
  }
}

// some constants
const ESC = '\x1b'; // 27
const FS = '\x1c'; // 28
const GS = '\x1d'; // 29

/// generic abstract commands class.
///
/// The derivated classes implements commands that can be sent to the printer
///
class Commands {
  List init = ['', ''];
  List bold = ['', ''];
  List underline = ['', ''];
  List underline2 = ['', ''];
  List reverse = ['', ''];
  List doubleSize = ['', ''];
  List doubleWidth = ['', ''];
  List doubleHeight = ['', ''];
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
