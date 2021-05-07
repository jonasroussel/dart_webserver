# Dart Web Server
[![pub package](https://img.shields.io/pub/v/dart_webserver.svg)](https://pub.dev/packages/dart_webserver)

A basic HTTP server framework built in Dart inspired by expressjs.

## Usage

```dart
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

void main() async {
  final app = WebServer();

  app.get('/', (req, res) {
    return 'Hello, World';
  });

  await app.listen(3000);
}
```
