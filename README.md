# dot_report

A simple report system for character based printers, mainly ESC/POS written in
pure dart.

## Features

The report system let you to create a `list of integers` that can be sent to
any character based printer.

It only produce the data to send, the way you use to send data depend on you,
under Flutter you can use some lib to send data with bluetooth or wifi. One
of them is: https://pub.dev/packages/bluetooth_thermal_printer

The main idea behind dot_report is to separate presentation from logic, and
let the user to modify presentation without recompile source, so in flutter you
can have a default reports and customized reports for each customer need.

Presentation script templates are written in yaml and contains placeholders
which are replaced at runtime with actual data. A snippet of report looks like this:

``` yaml
---
config:
  name: Test script
  description: invoice
  title: Invoice

bands:

  band:
    #          1         2         3         4--------
    # 123456789_123456789_123456789_123456789_12345678
    image: |
      \xxxxx \xxxxxxxxxxxxxxxxxxx \xx.xx \xx.xx \xx.xx

    values:
      - ["ED", "scu"]
      - ["W", "description"]
      - ["", "qt"]
      - ["", "price"]
      - ["", "qt*price"]

```

Each placeholder can be substituted with constants values or expressions from
variables coming from your application.

The expression evaluator used to resolve formulas can be configured, but my
choice is https://pub.dev/packages/expressions which is very powerful, and
can handle all types of data.

The system can handle fixed length forms for dot matrix printers and can be
used to print on chemical paper, but with some limitations on print style.

But the mot often usage in on thermic roll printers which do not need to
respect height, so graphics and double height fonts can be mixed with normal
fonts.

## Getting started

See on examples, pure dart example show some of the main features of the lib
and flutter example show how to integrate the lib in flutter.


## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder.

```dart
const like = 'sample';
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
