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
   * Constants
   */
  static final NOT_UPDATED = "not_updated";
  static final UPDATED = "updated";
  
  /**
   * Database
   */
  _SporranDatabase _database;
  
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
   *  Response getter for completion callbacks 
   */
  JsonObject _completionResponse;
  JsonObject get completionResponse => _completionResponse;
  
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
     * Construct our database.
     * Catch any exceptions from SporranDatabase, if we are offline ignore them.
     */
    try {
      
      _database = new _SporranDatabase(_dbName,
                                       hostName,
                                       port,
                                       scheme,
                                       userName,
                                       password);
      
    } catch (e) {
      
      if ( e is SporranException ) {
      
        if ( _online ) throw e;
        
      } else {
        
        throw e;
        
      }
    
    }
    
      
  }
  
  /**
   * Create Lawndart updated entry 
   */
  JsonObject _createUpdated(String key,
                           JsonObject payload) {
    
    /* Add our type marker and set to 'not updated' */
    JsonObject update = new JsonObject();
    update.type = NOT_UPDATED;
    update.payload = payload;
    return update;
    
    
  }
  
  /**
   * Create Lawndart not updated entry
   */
  JsonObject _createNotUpdated(String key,
                               JsonObject payload) {
    
    /* Add our type marker and set to 'not updated' */
    JsonObject update = new JsonObject();
    update.type = UPDATED;
    update.payload = payload;
    return update;
    
    
  }
  
  /**
   * Update LawnDart
   */
  void _updateLawnDart(String key,
                       JsonObject update,
                       String updateType) {
    
    /* Check for not initialized */
    if ( (_database.lawndart == null) || 
         (!_database.lawndart.isOpen ) )
      throw new SporranException("Initialisation Failure, Lawndart is not initialized");
    
    
    /* Do the update */
    JsonObject localUpdate = new JsonObject();
    if ( updateType == NOT_UPDATED) {
      localUpdate = _createNotUpdated(key,
                                      update);
    } else {
      localUpdate = _createUpdated(key,
          update);
    }
    _database._lawndart.save(localUpdate, key);
      
    
  }
  
  
  /**
   * Update document
   * If the document does not exist a create is performed
   */
  void put(String id,
           JsonObject document ){
    
    
    /* Update LawnDart */
    _updateLawnDart(id,
                    document,
                    NOT_UPDATED);
    
    
    /* If we are offline nothing to do */
    if ( !_online ) return;
    
    /* Check for not initialized */
    if ( _database.wilt == null ) throw new SporranException("Initialisation Failure, Wilt is not initialized");
    
    /* Complete locally, then boomerang to the client */
    var completer = (() {
      
      /* If success, mark the update as UPDATED in Lawndart */
      JsonObject res = _database.wilt.completionResponse;
      if ( !res.error) {
        
        JsonObject successResponse = res.jsonCouchResponse;
        _updateLawnDart(id,
            document,
            UPDATED);
        
      }
      
      _clientCompletion();
      
    });

    /* Do the put */
    _database.wilt.resultCompletion = completer;
    _database.wilt.putDocument(id, document);
    
    
  }
  
  /**
   * Get a document 
   */
  void get(String id,
           [String rev = null]) {
    
    /* Check for offline, if so try the get from LawnDart */
    if ( !_online ) {
      
      var getFuture = _database.lawndart.getByKey(id);
      _completionResponse = null;
      
      if ( getFuture != null ) {
        
        getFuture.then((document) {
          
          _completionResponse = document;
          _clientCompletion();
          
        });
        
      } else {
        
        _clientCompletion();
      }
        
    } else {
      
        var completer = ((_) {
      
          /* If Ok update Lawndart with the document */
         
          JsonObject res = _database.wilt.completionResponse;
          if ( !res.error ) {
        
            JsonObject successResponse = res.jsonCouchResponse;
            _updateLawnDart(id,
                            successResponse,
                            UPDATED);
            _completionResponse = successResponse;
            _clientCompletion();
            
          } else {
            
            _clientCompletion();
          }
          
        });
        
        _database.wilt.resultCompletion = completer;
        _completionResponse = null;
        _database.wilt.getDocument(id, rev:rev);
        
    }
    
      
  }
    
    
}