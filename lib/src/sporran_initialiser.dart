/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 10/09/2014
 * Copyright :  S.Hamblett@OSCF
 */

part of sporran;

/// Initialisation class, passed to Sporrans constructor
class SporranInitialiser {
  /// Database name
  String dbName;

  /// Hostname
  String hostname;

  /// Port
  String port;

  /// Scheme
  String scheme = 'http://';

  /// Username
  String username;

  /// Password
  String password;

  /// Manual notification control.
  ///
  /// Defaults to false, notifications are enabled by default.
  /// If set to true the user must perform their own syncing
  /// with CouchDB by calling the sync() method.
  bool manualNotificationControl = false;

  /// Preserve local storage
  ///
  /// On construction Sporran clears local storage by default,
  /// setting this to true preserves the local database.
  bool preserveLocal = false;
}
