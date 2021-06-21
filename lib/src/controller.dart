import 'handler.dart';
import 'utils.dart';

abstract class RequestController {
  RequestController(this.handlers);

  final List<RequestHandler>? handlers;

  bool match(Request req);

  Future<dynamic> handleRequest(
    Request req,
    Response res,
    NextFunction next,
  ) async {
    if (handlers == null) return next;

    for (var handler in handlers!) {
      var result = await handler(req, res, next);

      if (result is Future) result = await result;
      if (result != next) return result;
    }

    return next;
  }
}

class Route extends RequestController {
  Route({
    required this.path,
    required this.method,
    List<RequestHandler> handlers = const [],
  })  : pattern = patternFrom(path),
        super(handlers);

  final String path;
  final String method;
  final RegExp pattern;

  @override
  bool match(Request req) =>
      (req.method == method || req.method == 'HEAD' && method == 'GET') &&
      (pattern.hasMatch(req.path));

  @override
  Future handleRequest(Request req, Response res, NextFunction next) {
    parseParams(req, this);
    return super.handleRequest(req, res, next);
  }

  @override
  String toString() => '$path';
}

class Router extends RequestController {
  Router() : super(null);

  final List<RequestController> controllers = [];

  void use(RequestController controller) {
    controllers.add(controller);
  }

  void get(
    String path,
    RequestHandler handler, {
    List<RequestHandler> middlewares = const [],
  }) =>
      use(Route(
          path: trimSlash(path),
          method: 'GET',
          handlers: [...middlewares, handler]));

  void post(
    String path,
    RequestHandler handler, {
    List<RequestHandler> middlewares = const [],
  }) =>
      use(Route(
          path: trimSlash(path),
          method: 'POST',
          handlers: [...middlewares, handler]));

  void patch(
    String path,
    RequestHandler handler, {
    List<RequestHandler> middlewares = const [],
  }) =>
      use(Route(
          path: trimSlash(path),
          method: 'PATCH',
          handlers: [...middlewares, handler]));

  void put(
    String path,
    RequestHandler handler, {
    List<RequestHandler> middlewares = const [],
  }) =>
      use(Route(
          path: trimSlash(path),
          method: 'PUT',
          handlers: [...middlewares, handler]));

  void delete(
    String path,
    RequestHandler handler, {
    List<RequestHandler> middlewares = const [],
  }) =>
      use(Route(
          path: trimSlash(path),
          method: 'DELETE',
          handlers: [...middlewares, handler]));

  void options(
    String path,
    RequestHandler handler, {
    List<RequestHandler> middlewares = const [],
  }) =>
      use(Route(
          path: trimSlash(path),
          method: 'OPTIONS',
          handlers: [...middlewares, handler]));

  @override
  bool match(Request req) => true;

  @override
  Future<dynamic> handleRequest(
    Request req,
    Response res,
    void Function() next,
  ) async {
    for (var controller in controllers) {
      if (!controller.match(req)) continue;

      var result = await controller.handleRequest(req, res, next);

      if (result is Future) result = await result;
      if (result != next) return result;
    }

    return next;
  }
}
