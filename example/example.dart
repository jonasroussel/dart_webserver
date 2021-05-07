import 'package:dart_webserver/dart_webserver.dart';

void main() async {
  final app = WebServer();

  app.get('/', (req, res) {
    return 'Hello, World';
  });

  await app.listen(3000);
}
