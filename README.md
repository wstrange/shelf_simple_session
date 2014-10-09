
### shelf_simple_session 

A very simple cookie based session handler for dart Shelf middleware. 

Here is an example of usage (see example/session_example.dart)

```
    // simple handler that increments a counter stored in the session
      shelf.Response pingHandler(shelf.Request request) {
      
        // session() function gets a reference to the session map
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

```


### TO DO

This is super simple, and there are lots of enhancements that should be made:
- The session maintenance / timeout code is not efficient
- This wont work in a multi-isolate environment (needs some of way
of sharing session data between isolates)
- When Shelf gets proper cookie handling, the cookie code in here should
be replaced
- Tests. Could use some
- Implement session data encryption

