import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class ElementaryStreamServer {
  HttpServer? _server;
  final Set<HttpResponse> _clients = <HttpResponse>{};
  String? _path;

  String? get url {
    final server = _server;
    final path = _path;
    if (server == null || path == null) {
      return null;
    }
    return 'http://${server.address.address}:${server.port}$path';
  }

  Future<void> start({
    required String path,
    required String mimeType,
  }) async {
    await stop();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    _server = server;
    _path = normalizedPath;

    server.listen((request) {
      if (request.uri.path != normalizedPath) {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
        return;
      }

      final response = request.response;
      response.headers.set(HttpHeaders.contentTypeHeader, mimeType);
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      response.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
      response.bufferOutput = false;
      _clients.add(response);
      response.done.whenComplete(() {
        _clients.remove(response);
      });
    });
  }

  void push(Uint8List chunk) {
    final stale = <HttpResponse>[];
    for (final client in _clients) {
      try {
        client.add(chunk);
        unawaited(client.flush());
      } catch (_) {
        stale.add(client);
      }
    }
    _clients.removeAll(stale);
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _path = null;

    for (final client in _clients) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clients.clear();

    if (server != null) {
      await server.close(force: true);
    }
  }
}
