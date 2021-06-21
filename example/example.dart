import 'package:dart_webserver/dart_webserver.dart';

void main() async {
  final app = WebServer();

  app.get('/', (req, res, next) async {
    return 'Hello, World';
  });

  await app.bind(3000);

  Debug.info('Server started! http://localhost:3000');
}
