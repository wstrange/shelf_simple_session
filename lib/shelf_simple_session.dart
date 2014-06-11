import 'package:shelf/shelf.dart' as shelf;
import 'dart:io'; // for Cookie
import 'dart:async'; //timer
import 'package:logging/logging.dart';
import 'package:shelf_simple_session/cookie.dart' as cookie;
import 'package:shelf_simple_session/session.dart';
import 'dart:collection';


// default name of session cookie we use to remember session state id
const String _SESSION_COOKIE = 'DARTSIMPLESESSION';

var _logger = new Logger("shelf_simple_session");




/**
 * A simple [SessionStore] that uses an in memory Map for session data. The Map is
 * not replicated across isolates or other VM instances and will not survive server restarts.
 *
 * todo: implement a smarter way of purging expired sessions
 * todo: Remove dependency on dart:io when shelf has cookie support
 *  [https://code.google.com/p/dart/issues/detail?id=18845]
 * todo: implement encrypted map entries
 */
class SimpleSessionStore extends SessionStore {
  String _sessionCookieName;
  //String get sessionCookieName => _sessionCookieName;
  Timer _sessionTimer;
  // Session Map - keyed by session id
  Map<String,Session> _sessionMap = {};

  // todo:
  // Session expiry Map - sorted and keyed by Session expiry time.
  ///Map<DateTime,Session> _timeoutMap = new SplayTreeMap<DateTime,Session>();


   static var DURATION = const Duration(seconds:60);

   Timer _startSessionTimer() {
     return new Timer.periodic(DURATION,  (Timer t) => _maintainSessions() );
   }


   // periodically purge expired sessions
   // todo: this is simple but terribly inefficient. Use a better data structure that is sorted by
   // expiration date. The timer should run only when the next session is set to expire
  _maintainSessions() {
    _logger.finest("maintainSession");
    _sessionMap.keys
      .where( (k) => _sessionMap[k].isExpired())
      .toList()
      .forEach( (s) => destroySession(s));
  }


  /**
   * Create a new Simple Store with optional overrides for
   * [sessionIdleTime] - the time the session can be idle,
   * [sessionLifeTime]  the maximum time the session stays alive for
   * [cookieName] the name of the cookie that will be used to store the session id. Defaults to
   * DARTSIMPLESESSION.
   *
   */

  SimpleSessionStore({Duration sessionIdleTime: const Duration(seconds:60),
              Duration sessionLifeTime : const Duration(seconds:3600),
              String cookieName : _SESSION_COOKIE,
              SessionCallback onTimeout,
              SessionCallback onDestroy})
              :super(sessionIdleTime, sessionLifeTime, onTimeout: onTimeout, onDestroy:onDestroy) {
    _sessionCookieName = cookieName;
    _sessionTimer = _startSessionTimer();
  }

  // todo - should this set a cookie with 0 expiry time?
  destroySession(Session session) {
    var sess = this._sessionMap.remove(session.id);
    if( sess != null ) {
      if( this.onDestroy != null)
        this.onDestroy(sess);
    }
  }

  /**
   * Create a session cookie to send to the users browser.
   * TODO: Replace with shelf cookie class when available
   */
  Cookie _makeSessionCookie(shelf.Request req, Session session) {
    var c = new Cookie(_sessionCookieName, session.id);
    c.path = '/'; // the session cookie should be for all paths and subpaths
    // should we specify the domain or let it default?
    //c.domain = req.requestedUri.host;
    c.httpOnly = true; // prevent javascript, etc. from reading cookie
    // expiry?
    c.maxAge = this.maxSessionTime.inSeconds; // set cookie expiry time
    return c;
  }

  Session _createSession() {
    var session = new Session(this);
    _sessionMap[session.id] = session;
    return session;
  }

  /**
   * Called by the middleware to set up the session for downstream middlware and handlers.
   * This puts the session in the context
   */
  shelf.Request loadSession(shelf.Request request) {
    var cookieMap = cookie.parseCookies(request.headers);
    var sessionIdCookie = cookieMap[_sessionCookieName];
    _logger.finest("Looking for $_sessionCookieName cookie value = $sessionIdCookie");

    var session = null;
    if (sessionIdCookie == null) {
      _logger.fine("${_sessionCookieName} cookie not found. Creating new session");
      session = _createSession();
    }
    else {
      session = _sessionMap[sessionIdCookie.value];
      if( session == null ) {
        _logger.finest("Session cookie found, but no session found. Maybe server was restarted? Creating new session");
        session = _createSession();
      }
      else
         session.markAccessed();
    }

    // add the session to the context
    // so downstream middleware / handlers can call session(request)
    var r = request.change(context: {CTX_SESSION_KEY: session});
    return r;
  }


  shelf.Response storeSession(shelf.Request request, shelf.Response response) {
    var session = request.context[CTX_SESSION_KEY];
    _logger.finest("req context = ${request.context} Response context = ${response.context}");
    var sessionIdCookie = _makeSessionCookie(request,session);
    _logger.finest("Saving sesssion cookie=$sessionIdCookie");
    var nr = response.change(headers: {
             'set-cookie': sessionIdCookie.toString()
           });
    return nr;
  }

}

