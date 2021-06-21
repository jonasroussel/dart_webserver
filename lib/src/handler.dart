import 'dart:convert';
import 'dart:io';

import 'utils.dart';

typedef NextFunction = void Function();

typedef RequestHandler = dynamic Function(
  Request req,
  Response res,
  NextFunction next,
);

class Request {
  Request(this._httpRequest)
      : times = [DateTime.now()],
        path = trimSlash(_httpRequest.uri.path);

  HttpHeaders get headers => _httpRequest.headers;
  String get method => _httpRequest.method;
  HttpConnectionInfo? get connectionInfo => _httpRequest.connectionInfo;
  List<Cookie> get cookies => _httpRequest.cookies;
  String get protocolVersion => _httpRequest.protocolVersion;

  final List<DateTime> times;
  final String path;
  final Map<String, dynamic> query = {};
  late final dynamic body;
  late final ContentType? contentType;
  final Map<String, String> params = {};

  final HttpRequest _httpRequest;

  dynamic state;

  bool get hasBody => body != null;
}

Future<void> parseQueryAndBody(Request req) async {
  // parse query
  final queryParametersAll = req._httpRequest.uri.queryParametersAll;
  for (var queryParam in queryParametersAll.entries) {
    req.query[queryParam.key] = queryParam.value.first;
  }

  // parse body
  if (req._httpRequest.headers.contentType?.mimeType == 'application/json') {
    try {
      var content = await utf8.decoder.bind(req._httpRequest).join();
      req.body = json.decode(content);
      req.contentType = ContentType.json;
    } catch (ex) {
      req.body = null;
    }
  } else if (req._httpRequest.headers.contentType?.mimeType == 'text/plain') {
    req.body = await utf8.decoder.bind(req._httpRequest).join();
    req.contentType = ContentType.text;
  } else {
    req.body = null;
  }
}

class Response {
  Response(this._httpRequest);

  int get status => _httpRequest.response.statusCode;
  set status(int status) => _httpRequest.response.statusCode = status;

  List<Cookie> get cookies => _httpRequest.response.cookies;

  HttpHeaders get headers => _httpRequest.response.headers;

  final HttpRequest _httpRequest;
}
