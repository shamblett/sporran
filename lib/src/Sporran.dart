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
  static final _NOT_UPDATED = "not_updated";
  static final _UPDATED = "updated";
  
  static final PUT = "put";
  static final GET = "get";
  
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
  var _clientCompleter;
  set clientCompleter(var completer) => _clientCompleter = completer;
  
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
     */
      
     _database = new _SporranDatabase(_dbName,
                                       hostName,
                                       port,
                                       scheme,
                                       userName,
                                       password);    
  }
  
  /**
   * Create Lawndart updated entry 
   */
  JsonObject _createUpdated(String key,
                           JsonObject payload) {
    
    /* Add our type marker and set to 'not updated' */
    JsonObject update = new JsonObject();
    update.type = _NOT_UPDATED;
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
    update.type = _UPDATED;
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
    if ( updateType == _NOT_UPDATED) {
      localUpdate = _createNotUpdated(key,
                                      update);
    } else {
      localUpdate = _createUpdated(key,
          update);
    }
    _database._lawndart.save(localUpdate, key);
      
    
  }
  
  JsonObject _createCompletionResponse(JsonObject result) {
    
    JsonObject completion = new JsonObject();
    
    completion.operation = result.operation;
    completion.payload = null;
    
    /**
     * Check for a Lawndart or Wilt response 
     */
    if ( result.lawnResponse ) {
       
      completion.ok = result.ok;
      if ( completion.ok ) completion.payload = result.payload;
      
    } else {
      
      if ( result.error ) {
        
        completion.ok = false;
        completion.errorCode = result.errorCode;
        completion.errorText = result.jsonCouchResponse.error;
        completion.errorReason = result.jsonCouchResponse.reason;
        
      } else {
        
        completion.ok = true;
        completion.payload = result.jsonCouchResponse;
        
      }
      
    }
    
    return completion;
      
  }
  
  /**
   * Update document
   * If the document does not exist a create is performed
   */
  void put(String id,
           JsonObject document){
    
    /* Update LawnDart */
    _updateLawnDart(id,
                    document,
                    _NOT_UPDATED);
    
    
    /* If we are offline just return */
    if ( !_online ) {
      
      return;
      
    }
    
    /* Check for not initialized */
    if ( _database.wilt == null ) throw new SporranException("Initialisation Failure, Wilt is not initialized");
    
    /* Complete locally, then boomerang to the client */
    void completer() {
      
      /* If success, mark the update as UPDATED in Lawndart */
      JsonObject res = _database.wilt.completionResponse;
      if ( !res.error) {
        
        JsonObject successResponse = res.jsonCouchResponse;
        _updateLawnDart(id,
            document,
            _UPDATED);
        
      }
      res.lawnResponse = false;
      res.operation = PUT;
      _completionResponse = _createCompletionResponse(res);
      _clientCompleter();
      
    };

    /* Do the put */
    _database.wilt.completionResponse;
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
        
        _database.lawndart.getByKey(id).then((document) {
         
          JsonObject res = new JsonObject();
          if ( document == null ) {
                    
            res.lawnResponse = true;
            res.operation = GET;
            res.ok = false;
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
            
          } else {
            
            res.lawnResponse = true;
            res.operation = GET;
            res.ok = true;
            res.payload = new JsonObject.fromMap(document['payload']);
            _completionResponse = _createCompletionResponse(res);
          
          }
         
          _clientCompleter();
          
        });
        
        
    } else {
      
        void completer(){
      
          /* If Ok update Lawndart with the document */
         
          JsonObject res = _database.wilt.completionResponse;
          if ( !res.error ) {
        
            JsonObject successResponse = res.jsonCouchResponse;
            _updateLawnDart(id,
                             successResponse,
                            _UPDATED);
            res.lawnResponse = false;
            res.operation = GET;
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
            
          } else {
            
            res.lawnResponse = false;
            res.operation = GET;
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
            
          }
          
        };
        
        _database.wilt.resultCompletion = completer;
        _database.wilt.getDocument(id, rev:rev);
        
    }
    
      
  }
    
}