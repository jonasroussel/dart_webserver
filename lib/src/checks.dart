import 'package:ansicolor/ansicolor.dart';
import 'package:dart_webserver/src/debug.dart';

import 'controller.dart';
import 'server.dart';

Map<int, List<Route>> _mapByDepth(Router router) {
  var map = <int, List<Route>>{};

  for (var ctrl in router.controllers) {
    if (ctrl is Router) {
      map.addAll(_mapByDepth(ctrl));
    } else if (ctrl is Route) {
      final depth = ctrl.path.split('/').length - 1;

      if (!map.containsKey(depth)) {
        map[depth] = [ctrl];
      } else {
        map[depth]!.add(ctrl);
      }
    }
  }

  return map;
}

void checkRoutesReachability(WebServer server) {
  var depthMap = _mapByDepth(server);

  for (var depth in depthMap.keys) {
    var routes = depthMap[depth]!;

    for (var route in routes) {
      var otherRoutes = routes.takeWhile((value) {
        return value.path != route.path;
      }).toList();

      for (var target in otherRoutes) {
        if (target.method == route.method &&
            target.pattern.hasMatch(route.path)) {
          Debug.warning('${route.path} is not reachable!');
          break;
        }
      }
    }
  }
}
