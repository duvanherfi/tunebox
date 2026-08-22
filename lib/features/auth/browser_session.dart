import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Empties the cookie jar the login browser keeps.
///
/// It is the platform's own store — `WKWebsiteDataStore` here, Android's
/// `CookieManager` there — so it survives the app being closed and belongs to
/// nobody in particular. [LoginScreen] harvests from it; signing out has to
/// empty it, or Google stays signed in and the next sign-in cannot be anyone
/// else.
Future<void> forgetBrowserSession() async {
  await CookieManager.instance().deleteAllCookies();
}
