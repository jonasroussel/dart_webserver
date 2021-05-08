import 'dart:convert';
import 'dart:io';

typedef RequestHandler = dynamic Function(
  Request req,
  Response res,
  void Function() next,
);
typedef RequestEndpoint = dynamic Function(Request req, Response res);

class Route {
  Route(this.path, this.handlers);

  final String path;
  final List<Function> handlers;
}

class Request {
  Request(this._request)
      : headers = _request.headers,
        method = _request.method,
        url = _request.uri.path,
        connectionInfo = _request.connectionInfo,
        cookies = _request.cookies,
        protocalVersion = _request.protocolVersion;

  final HttpHeaders headers;
  final String method;
  final String url;
  final HttpConnectionInfo? connectionInfo;
  final List<Cookie> cookies;
  final String protocalVersion;

  final Map<String, dynamic> query = {};
  late final dynamic body;
  late final ContentType? contentType;
  final Map<String, String> params = {};

  final HttpRequest _request;

  bool get hasBody => body != null;

  Future<void> parseQueryAndBody() async {
    // parse query
    final queryParametersAll = _request.uri.queryParametersAll;
    for (var queryParam in queryParametersAll.entries) {
      query[queryParam.key] = queryParam.value.first;
    }

    // parse body
    if (_request.headers.contentType?.mimeType == 'application/json') {
      try {
        var content = await utf8.decoder.bind(_request).join();
        body = jsonDecode(content);
        contentType = ContentType.json;
      } catch (ex) {
        body = null;
      }
    } else if (_request.headers.contentType?.mimeType == 'text/plain') {
      body = await utf8.decoder.bind(_request).join();
      contentType = ContentType.text;
    } else {
      body = null;
    }
  }

  void parseParams(Route route) {
    var pathSegments = route.path.split('/');
    var uriSegments = _request.uri.path.split('/');

    for (var i = 0; i < pathSegments.length; i++) {
      if (pathSegments[i].startsWith(':') && pathSegments[i].length > 1) {
        params[pathSegments[i].substring(1)] = uriSegments[i];
      }
    }
  }
}

class Response {
  Response(this._request);

  int get status => _request.response.statusCode;
  set status(int status) => _request.response.statusCode = status;

  List<Cookie> get cookies => _request.response.cookies;

  HttpHeaders get headers => _request.response.headers;

  final HttpRequest _request;
}

class WebServer {
  WebServer();

  final Map<String, List<RequestHandler>> _middlewares = {};
  final List<RegExp> _paths = [];
  final List<Map<String, Route>> _binds = [];

  void _route(
    String path,
    RequestEndpoint endpoint, {
    List<RequestHandler> middlewares = const [],
    String? method,
  }) {
    final pattern = _pattern(path);
    final idx = _paths.indexWhere((regex) => regex.pattern == pattern);

    if (idx == -1) {
      _paths.add(RegExp(pattern));
      final route = Route(path, [...middlewares, endpoint]);
      final bind = method == null
          ? <String, Route>{
              'GET': route,
              'POST': route,
              'PATCH': route,
              'PUT': route,
              'DELETE': route,
              'OPTIONS': route,
            }
          : <String, Route>{method: route};
      _binds.add(bind);
      return;
    }

    if (method == null) return;

    var bind = _binds[idx];
    var handlers = bind[method];

    if (handlers != null) return;

    _binds[idx][method] = Route(path, [...middlewares, endpoint]);
  }

  void use(RequestHandler handler, {String? method}) {
    if (method != null) {
      final handlers = _middlewares[method];
      if (handlers == null) {
        _middlewares[method] = [handler];
      } else {
        _middlewares[method]!.add(handler);
      }
    } else {
      use(handler, method: 'GET');
      use(handler, method: 'POST');
      use(handler, method: 'PATCH');
      use(handler, method: 'PUT');
      use(handler, method: 'DELETE');
      use(handler, method: 'OPTIONS');
    }
  }

  void get(
    String path,
    RequestEndpoint endpoint, {
    List<RequestHandler> middlewares = const [],
  }) {
    _route(
      path,
      endpoint,
      middlewares: middlewares,
      method: 'GET',
    );
  }

  void post(
    String path,
    RequestEndpoint endpoint, {
    List<RequestHandler> middlewares = const [],
  }) {
    _route(
      path,
      endpoint,
      middlewares: middlewares,
      method: 'POST',
    );
  }

  void patch(
    String path,
    RequestEndpoint endpoint, {
    List<RequestHandler> middlewares = const [],
  }) {
    _route(
      path,
      endpoint,
      middlewares: middlewares,
      method: 'PATCH',
    );
  }

  void put(
    String path,
    RequestEndpoint endpoint, {
    List<RequestHandler> middlewares = const [],
  }) {
    _route(
      path,
      endpoint,
      middlewares: middlewares,
      method: 'PUT',
    );
  }

  void delete(
    String path,
    RequestEndpoint endpoint, {
    List<RequestHandler> middlewares = const [],
  }) {
    _route(
      path,
      endpoint,
      middlewares: middlewares,
      method: 'DELETE',
    );
  }

  void options(
    String path,
    RequestEndpoint endpoint, {
    List<RequestHandler> middlewares = const [],
  }) {
    _route(
      path,
      endpoint,
      middlewares: middlewares,
      method: 'OPTIONS',
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final req = Request(request);
    await req.parseQueryAndBody();
    final res = Response(request);
    final next = () {};

    if (_middlewares[request.method] != null) {
      for (var handler in _middlewares[request.method]!) {
        var result = handler(req, res, next);

        if (result is Future) result = await result;
        if (result == next) continue;

        var content;

        if (result is String || result is num) {
          content = result.toString();
        } else if (result is Map<String, dynamic> || result is List) {
          try {
            content = jsonEncode(result);
            request.response.headers.contentType = ContentType.json;
          } catch (ex) {
            return;
          }
        } else if (result != null) {
          try {
            content = jsonEncode(result.toJson());
            request.response.headers.contentType = ContentType.json;
          } catch (ex) {
            return;
          }
        }

        if (content != null) {
          request.response.contentLength = content.toString().length;
          request.response.write(content);
        }

        break;
      }
    }

    final index = _paths
        .indexWhere((regex) => regex.hasMatch(_trimSlash(request.uri.path)));

    if (index == -1) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }

    final bind = _binds[index];
    final route = bind[request.method];

    if (route == null) {
      request.response.statusCode = HttpStatus.methodNotAllowed;
      return;
    }

    req.parseParams(route);

    for (var handler in route.handlers) {
      request.response.statusCode = HttpStatus.ok;

      var result = handler.runtimeType == RequestHandler
          ? handler(req, res, next)
          : handler(req, res);

      if (result is Future) result = await result;
      if (result == next) continue;

      var content;

      if (result is String || result is num) {
        content = result.toString();
      } else if (result is Map<String, dynamic> || result is List) {
        try {
          content = jsonEncode(result);
          request.response.headers.contentType = ContentType.json;
        } catch (ex) {
          return;
        }
      } else if (result != null) {
        try {
          content = jsonEncode(result.toJson());
          request.response.headers.contentType = ContentType.json;
        } catch (ex) {
          return;
        }
      }

      if (content != null) {
        request.response.contentLength = content.toString().length;
        request.response.write(content);
      }

      break;
    }
  }

  String _pattern(String path) {
    var segments = path.split('/')..removeAt(0);
    var pattern = '^';

    for (var segment in segments) {
      if (segment.startsWith(':')) {
        pattern += '/[^/]+';
      } else if (segment.isNotEmpty) {
        pattern += '/$segment';
      }
    }

    pattern += '\$';

    return pattern;
  }

  String _trimSlash(String str) =>
      str.endsWith('/') ? str.substring(0, str.length - 1) : str;

  Future<void> listen(int port) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    await for (HttpRequest request in server) {
      await _handleRequest(request);
      await request.response.close();
    }
  }
}
