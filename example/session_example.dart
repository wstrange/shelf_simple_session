import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_simple_session/shelf_simple_session.dart';
import 'package:shelf_simple_session/session.dart';

import 'dart:io';
import 'package:logging/logging.dart';

/**
 * Small example showing session management
 */

void main() {

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.loggerName} ${rec.message}');
  });

  // simple handler that increments a counter stored in the session
  shelf.Response pingHandler(shelf.Request request) {
    var map = session(request);
    var c = map['counter'];
    int counter = ( c == null ? 0 : c) +1;
    //store counter in the session
    map['counter'] = counter;

    return new shelf.Response.ok("ping counter=$counter");
  }


  var handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addMiddleware(sessionMiddleware(new SimpleSessionStore()))
      .addHandler(pingHandler);

  // listen on port 7001
  io.serve(handler, InternetAddress.ANY_IP_V4, 7001);
}
