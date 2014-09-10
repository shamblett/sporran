/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 10/09/2014
 * Copyright :  S.Hamblett@OSCF
 */

part of sporran;

/**
 * Initialisation class, passed to Sporrans constructor
 */
class SporranInitialiser {

  /**
   * Database name
   */
  String _dbName;
  String get dbName => _dbName;
  set dbName(String name) => _dbName = name;

  /**
   *  Hostname
   */
  String _hostname;
  String get hostname => _hostname;
  set hostname(String name) => _hostname = name;

  /**
   * Port
   */
  String _port;
  String get port => _port;
  set port(String port) => port = port;
  
  /**
   *  Scheme
   */
  String _scheme = 'http://';
  String get scheme => _scheme;
  set scheme(String scheme) => _scheme = scheme;
  
  /**
   *  Username
   */
  String _username;
  String get username => _username;
  set username(String name) => _username = name;

  /**
   *  Password
   */
  String _password;
  String get password => _password;
  set password(String password) => _password = password;
  
  /**
   * Manual notification control.
   * 
   * Defaults to false, notifications are enabled by default.
   * If set to true the user must perform their own syncing
   * with CouchDB by calling the sync() method.
   */
  bool _manualNotificationControl = false;
  bool get manualNotificationControl => _manualNotificationControl;
  set manualNotificationControl(bool flag) => _manualNotificationControl = flag;
  
  /**
   * Preserve local storage
   * 
   * On construction Sporran clears local storage by default, 
   * setting this to true preserves the local database.
   */
  bool _preserveLocal = false;
  bool get preserveLocal => _preserveLocal;
  set preserveLocal(bool flag) => _preserveLocal = flag;

}
