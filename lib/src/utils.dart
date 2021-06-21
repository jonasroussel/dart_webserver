import 'controller.dart';
import 'handler.dart';

RegExp patternFrom(String path) {
  var segments = path.split('/')..removeAt(0);
  var pattern = '^';

  for (var segment in segments) {
    if (segment.startsWith(':')) {
      pattern += '/[^/]+';
    } else if (segment.isNotEmpty) {
      pattern += '/$segment';
    }
  }

  if (pattern == '^') pattern += '/';
  pattern += '\$';

  return RegExp(pattern);
}

void parseParams(Request req, Route route) {
  var pathSegments = route.path.split('/');
  var uriSegments = req.path.split('/');

  for (var i = 0; i < pathSegments.length; i++) {
    if (pathSegments[i].startsWith(':') && pathSegments[i].length > 1) {
      req.params[pathSegments[i].substring(1)] = uriSegments[i];
    }
  }
}

String trimSlash(String str) => !str.startsWith('/') && str.endsWith('/')
    ? str.substring(0, str.length - 1)
    : str;
