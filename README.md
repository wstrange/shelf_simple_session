
### shelf_simple_session 

A very simple session handler for dart Shelf middleware. 

This is "demo quality". I am expecting a better / higher quality session manager to come from the dart team. 

Here is an example of usage (see bin/session_example.dart)


    // simple handler that increments a counter stored in the session
      shelf.Response pingHandler(shelf.Request request) {
        var map = session(request);
        var c = map['counter'];
        int counter = ( c == null ? 0 : c) +1;
        //store counter in the session
        map['counter'] = counter;
    
        return new shelf.Response.ok("ping counter=$counter");
      }
    
      var sm  = new SimpleSessionManager();
    
      var handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addMiddleware(sessionMiddleware(sm))
          .addHandler(pingHandler);
    
      // listen on port 7001
      io.serve(handler, InternetAddress.ANY_IP_V4, 7001);




