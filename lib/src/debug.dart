import 'package:ansicolor/ansicolor.dart';

class Debug {
  static bool enabled = true;

  static final _info = AnsiPen()..cyan();
  static final _warning = AnsiPen()..magenta();
  static final _error = AnsiPen()..red(bold: true);

  static void info(Object? value) {
    if (!enabled) return;
    print(_info('[INFO] $value'));
  }

  static void warning(Object? value) {
    if (!enabled) return;
    print(_warning('[WARNING] $value'));
  }

  static void error(Object? value) {
    if (!enabled) return;
    print(_error('[ERROR] $value'));
  }
}
