import 'dart:convert';
import 'dart:io';

import 'checks.dart';
import 'debug.dart';
import 'handler.dart';
import 'controller.dart';
import 'utils.dart';

class WebServer extends Router {
  WebServer();

  Future<void> bind(
    int port, {
    InternetAddress? address,
    bool runChecks = true,
  }) async {
    if (runChecks) {
      _checks();
    }

    final server = await HttpServer.bind(
      address ?? InternetAddress.anyIPv6,
      port,
    );

    _awaitForRequests(server);
  }

  void _checks() {
    checkRoutesReachability(this);
  }

  void _awaitForRequests(HttpServer server) async {
    await for (HttpRequest request in server) {
      await _handleRequest(request);
      await request.response.close();
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final req = Request(request);
      await parseQueryAndBody(req);
      req.times.add(DateTime.now());
      final res = Response(request);
      final next = () {};

      final result = await handleRequest(req, res, next);
      req.times.add(DateTime.now());

      if (result == next) {
        res.status = HttpStatus.notFound;
      } else if (result != null) {
        request.response.headers.contentType = ContentType.json;

        if (req.method != 'HEAD') {
          final content = json.encode(result);
          request.response.contentLength = content.length;
          request.response.write(content);
        }
      }
      req.times.add(DateTime.now());

      final parsingTime = req.times[1].difference(req.times[0]).inMilliseconds;
      final handlingTime = req.times[2].difference(req.times[1]).inMilliseconds;
      final writingTime = req.times[3].difference(req.times[2]).inMilliseconds;

      Debug.info(
          '${req.path} (parsing: $parsingTime ms, handling: $handlingTime ms, writing: $writingTime ms)');
    } catch (exception, stack) {
      print('Unhandled exception: ${request.uri.path}\n$exception\n$stack');
      request.response.statusCode = HttpStatus.internalServerError;
    }
  }
}
