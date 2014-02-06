/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 * 
 * Sporran allows clients to use databse facilities in both online and offline browser modes.
 * 
 * It uses Lawndart as a shadow database for CouchDb where all updates are written to Lawndart and
 * marked as 'not updated', then written to CouchDb, if the write succeeds the Lawndart update
 * is now marked as 'updated'. Similarly database reads which complete  successfully in CouchDb are 
 * updated locally before returning the result to the client. In parallel with this change notifications
 * are reieved from CouchDb and the local database synced where needed.
 * 
 * This allows the client to continue working offline, when returniing to online Sporran automatically
 * writes all 'not updated' entries to CouchDb and proceses any other change notifications as normal.
 * 
 * The online/Offline browser events trigger automatic switching between online and offline modes, the
 * client can however set this mode himself whenever he choses.
 * 
 */

part of sporran;

class Sporran {
  
  
  /**
   * Database
   */
  SporranDatabase _database;
  
  /**
   * Database name
   */
  String _dbName;
  String get dbName => _dbName;
  
  /**
   * On/Offline indicator
   */
  bool _online = true;
  bool get online => _online;
  set online(bool state) => _online = state;
  
  
  /**
   * Completion function 
   */
  var _clientCompletion;
  set resultCompletion (var completion ) => _clientCompletion = completion;
  
 
  /**
   * Construction
   */
  Sporran(this._dbName,
          String hostName,
          [String port = "5984",
           String scheme = "http://",
           String userName = null,
           String password = null]) {
    
    
    /**
     * Construct our database 
     */
    _database = new SporranDatabase(_dbName,
                                    hostName,
                                    port,
                                    scheme,
                                    userName,
                                    password);
    
    
  }
  
  
}