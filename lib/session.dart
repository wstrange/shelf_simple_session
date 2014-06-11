library session;
import 'package:shelf/shelf.dart' as shelf;
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'dart:collection';
import 'dart:async';

// Key used to store the session in the shelf context
const String CTX_SESSION_KEY = 'shelf_session.simple_session';


/**
 * Top level function to retrieve the session
 * Handlers or middleware access the session using:
 *      var map = session(request);
 *      var foo = map['mydata']; // to read session data
 *      map['mykey'] = 'foo'; // to put data in the session
 */
Session session(shelf.Request req) {
  var session = req.context[CTX_SESSION_KEY] as Session;
  if (session == null) throw new StateError("Session not found in context. This is probably a programming error. Did you forget to put the session middleware before others?");
  return session;
}



/**
 * [Session] implements a Map interface that handlers can retreive and store values into.
 * The session can be accessed using the top level [session(request)] function.
 *
 */
class Session extends MapBase {
  Map _data = {};
  String _id;
  DateTime _created;
  DateTime _lastAccessed;
  SessionStore _sessionStore;
  DateTime _sessionExpiryTime;
  DateTime _idleExpiryTime;
  bool _destroyed = false;

  bool get isDestroyed => _destroyed;

  // Return the unique session id
  String get id => _id;

  // The [SessionStore] that manages this session
  SessionStore get sessionStore => _sessionStore;

  // Create a new [Session] passing in the reference to underlying [SessionStore]
  Session(this._sessionStore) {
    _id = _sessionStore.createSessionId();
    var now = new DateTime.now();
    _sessionExpiryTime = now.add(_sessionStore.maxSessionTime);
    _idleExpiryTime = now.add(_sessionStore.maxSessionIdleTime);
  }

  // Mark the current session as being accessed. This will reset the
  // idle timer.
  markAccessed() {
    _idleExpiryTime = new DateTime.now().add(_sessionStore.maxSessionIdleTime);
  }

  // compareTo - compare sessions
  // based on expiry time
  // not used right now... needed?
  //int compareTo(Session other)
  //    => this._nextExpiryTime().compareTo(other._nextExpiryTime());

  // Map implementation:
  // In a multi-server / multi-isolate environment these
  // methods will need to sync the data to the other session manager instances
  operator [](key) => _data[key];
  void operator []=(key, value) {
    _data[key] = value;
  }
  remove(key) => _data.remove(key);
  void clear() => _data.clear();
  Iterable get keys => _data.keys;

  String toString() => 'Session id:$id $_data';

  // The time the session expires - the lessor of idle time and expirty time
  DateTime _nextExpiryTime() => (_idleExpiryTime.isBefore(_sessionExpiryTime) ? _idleExpiryTime : _sessionExpiryTime);

  // return true if this session has expired
  bool isExpired() => _nextExpiryTime().isAfter(new DateTime.now());
}



// Callback handler for Session life cycle events
typedef void SessionCallback(Session);



/**
 * SessionStore is responsible for retrieving and storing the session data
 *
 * Session Life Cycle events:
 *  -Rather than each Session object store pointers to lifecycle events, we store these
 * at the SessionManager level. This means that you can not have unique handlers per Session.
 * This should be OK- since the handler is passed in the Session object
 *
 */
abstract class SessionStore {
  Duration _maxSessionIdleTime;
  // The max time the session can remain idle.
  Duration get maxSessionIdleTime => _maxSessionIdleTime;

  Duration _maxSessionTime;
  Duration get maxSessionTime => _maxSessionTime;

  // Optional Callback handlers to run on Session lifecycle events
  SessionCallback _onDestroy;
  SessionCallback _onTimeout;

  SessionCallback get onTimeout => _onTimeout;
  SessionCallback get onDestroy => _onDestroy;


  /**
   * Create a new [SessionStore]. Specify the maximum
   * time a session can be idle before it is destroyed, and the
   * maximum absolute time that a session can be alive for.
   * Optional Session life cycle callbacks can be passed
   */
  SessionStore(this._maxSessionIdleTime, this._maxSessionTime,
      {SessionCallback onTimeout, SessionCallback onDestroy}) {
    _onTimeout = onTimeout;
    _onDestroy = onDestroy;
   }

  // Load the session, creating a new session if no existing session is found
  // Returns a new [shelf.Request] that has the [Session] added to the shelf context.
  // [loadSession] must be called before any downstream handlers can access the session
  shelf.Request loadSession(shelf.Request request);
  // Save the session state.
  // Returns a [shelf.Response]. The response may return additional data
  // to the client. For example - by setting a Cookie with the unique session id
  shelf.Response storeSession(shelf.Request req, shelf.Response response);

  var _random = new math.Random();

  // generate a unique random session id
  // subclasses might override this to create a session id that is
  // unique to their implementation
  String createSessionId() {
    const int _KEY_LENGTH = 16; // 128 bits.
    var data = new List<int>(_KEY_LENGTH);
    for (int i = 0; i < _KEY_LENGTH; ++i) data[i] = _random.nextInt(256);

    return CryptoUtils.bytesToHex(data);
  }

  // Delete a [session]
  void destroySession(Session session);
}


/**
 * Create simple session middleware
 * Note this middleware MUST be in the chain BEFORE [session(request)] is called by downstream
 * handlers or middleware.
 * [sessionStore] - The Storage Handler that loads and stores the session.
 */
shelf.Middleware sessionMiddleware(SessionStore sessionStore) {
   return (shelf.Handler innerHandler) {
    return (shelf.Request request) {
      var r = sessionStore.loadSession(request);
      return new Future.sync(() => innerHandler(r)).then((shelf.Response response) {
        // persist session
        return sessionStore.storeSession(r, response);
      });
    };
  };
}

