library session;
import 'package:shelf/shelf.dart' as shelf;
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'dart:collection';
import 'dart:async';

// Key used to store the session in the shelf context
final String CTX_SESSION_KEY = 'shelf_simple_session';


/**
 * Top level function to retrieve the session
 * Handlers or middleware access the session using:
 *      var map = session(request);
 *      var foo = map['mydata']; // to read session data
 *      map['mykey'] = 'foo'; // to put data in the session
 */
Session session(shelf.Request req) {
  var session = req.context[CTX_SESSION_KEY] as Session;
  if (session == null) throw new StateError("Session context not found. This is probably a programming error. Did you forget to put the session middleware before others?");
  return session;
}


class Session extends MapBase  implements Comparable {
  Map _data = {};
  String _id;
  DateTime _created;
  DateTime _lastAccessed;
  SessionManager _sessionManager;
  DateTime _sessionExpiryTime;
  DateTime _idleExpiryTime;

  String get id => _id;

  Session(this._sessionManager) {
    _id = _sessionManager.createSessionId();
    var now = new DateTime.now();
    _sessionExpiryTime = now.add(_sessionManager.maxSessionTime);
    _idleExpiryTime = now.add(_sessionManager.maxSessionIdleTime);
    //_created = _lastAccessed = new DateTime.now();
  }

  //
  markAccessed() {
    _idleExpiryTime = new DateTime.now().add(_sessionManager.maxSessionIdleTime);
  }

  // compareTo - compare sesssions
  // based on expiry time
  // not used right now... needed?
  int compareTo(Session other)
      => this._nextExpiryTime().compareTo(other._nextExpiryTime());

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

  DateTime _nextExpiryTime() => (_idleExpiryTime.isBefore(_sessionExpiryTime) ? _idleExpiryTime : _sessionExpiryTime);

  bool isExpired() => _nextExpiryTime().isAfter(new DateTime.now());

}

abstract class SessionManager {

  Duration _maxSessionIdleTime;
  // The max time the session can remain idle.
  Duration get maxSessionIdleTime => _maxSessionIdleTime;

  Duration _maxSessionTime;
  Duration get maxSessionTime => _maxSessionTime;

  SessionManager(this._maxSessionIdleTime, this._maxSessionTime);

  shelf.Request prepareSession(shelf.Request request);
  shelf.Response saveSession(shelf.Request req, shelf.Response response);
  //Session getSession(shelf.Request request);

  var _random = new math.Random();

  // utility to generate a random session id
  // subclasses might override this to create a session id that is
  // unique to their implementation
  String createSessionId() {
    const int _KEY_LENGTH = 16; // 128 bits.
    var data = new List<int>(_KEY_LENGTH);
    for (int i = 0; i < _KEY_LENGTH; ++i) data[i] = _random.nextInt(256);

    return CryptoUtils.bytesToHex(data);
  }

}


/**
 * Create simple session middleware
 * Note this middleware MUST be in the chain BEFORE session(request) is called.
 * [sessionManager]
 */
shelf.Middleware sessionMiddleware(SessionManager sessionManager) {
  //var sm = (sessionManager == null ? new SimpleSessionManager(): sessionManager);

  return (shelf.Handler innerHandler) {
    return (shelf.Request request) {
      var r = sessionManager.prepareSession(request);
      return new Future.sync(() => innerHandler(r)).then((shelf.Response response) {
        // persist session
        return sessionManager.saveSession(r, response);
      });
    };
  };
}

