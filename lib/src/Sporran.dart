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
  static final DELETE = "delete";
  
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
   * Hot cache size
   */
  int get hotCacheSize => _database.length();
  
  /**
   * Pending delete queue size
   */
  int get pendingDeleteSize => _database.pendingLength();
  
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
   * Common completion response creator for all databases
   */
  JsonObject _createCompletionResponse(JsonObject result) {
    
    JsonObject completion = new JsonObject();
    
    completion.operation = result.operation;
    completion.payload = null;
    
    /**
     * Check for a local or Wilt response 
     */
    if ( result.localResponse ) {
       
      completion.ok = result.ok;
      
      /* Only have a payload for a GET response */
      if ( completion.ok ) {
        
        if ( result.operation == GET) completion.payload = result.payload;
        
      }
      
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
   * Create local storage updated entry 
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
   * Create local storage not updated entry
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
   * Update local storage
   */
  void _updateLocalStorageObject(String key,
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
    
    /**
     * Update the hot cache, then Lawndart.
     * When Lawndart has saved the item remove it from the
     * hot cache.
     */
    _database.put(key, localUpdate);
    _database._lawndart.save(localUpdate, key)
    ..then((String key) => _database.remove(key));
      
    
  }
  
  
  /**
   * Get from local storage
   */
  JsonObject _getLocalStorageObject(String key) {
    
    JsonObject localObject = new JsonObject();
    bool notFound = true;
    
    /**
     * Try Lawndart first then the hot cache
     */
    _database.lawndart.getByKey(key).then((document) {
      
      JsonObject res = new JsonObject();
      notFound = false;
      
      if ( document == null ) {
        
        /* Try the hot cache */
        JsonObject hotObject = _database.get(key);
        if ( hotObject == null ) {
          
          localObject = null;
          
        } else {
          
          localObject = hotObject;
        }
        
      } else {
        
        /* Got from Lawndart */
        
        localObject = document;
        
      }
      
    });
    
    /**
     * One last shot at the hot cache 
     */
    if ( notFound ) {
      
      JsonObject res = new JsonObject();
      JsonObject hotObject = _database.get(key);
      if ( hotObject == null ) {
        
        localObject = null;
        
      } else {
        
        localObject = hotObject;
      }
      
    }
    
    /* Either an object or null */
    return localObject;
    
  }
  
  /**
   * Delete from local storage
   */
  bool _deleteLocalStorageObject(String key) {
    
    bool keyExists = false;
    
    /* Remove from Lawndart */
    _database.lawndart.exists(key)
    ..then((bool exists) {
      
          if ( exists ) {
            
            _database.lawndart.removeByKey(key);
            keyExists = true;
            
          }
       });
    
    /* Remove from the hot cache */
    _database.remove(key);
    
    return keyExists;
    
  }
  
  /**
   * Update document
   * If the document does not exist a create is performed
   */
  void put(String id,
           JsonObject document){
    
    /* Update LawnDart */
    _updateLocalStorageObject(id,
                    document,
                    _NOT_UPDATED);
    
    
    /* If we are offline just return */
    if ( !_online ) {
      
      JsonObject res = new JsonObject();
      res.localResponse = true;
      res.operation = PUT;
      res.ok = true;
      _completionResponse = _createCompletionResponse(res);
      _clientCompleter();
      return;
      
    }
    
    /* Check for not initialized */
    if ( _database.wilt == null ) throw new SporranException("Initialisation Failure, Wilt is not initialized");
    
    /* Complete locally, then boomerang to the client */
    void completer() {
      
      /* If success, mark the update as UPDATED in local storage */
      JsonObject res = _database.wilt.completionResponse;
      res.ok = false;
      if ( !res.error) {
        
        JsonObject successResponse = res.jsonCouchResponse;
        _updateLocalStorageObject(id,
            document,
            _UPDATED);
        res.ok = true;
        
      }
      res.localResponse = false;
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
    
    /* Check for offline, if so try the get from local storage */
    if ( !_online ) {
        
        JsonObject document = _getLocalStorageObject(id);
         
        JsonObject res = new JsonObject();
        if ( document == null ) {
                    
          res.localResponse = true;
          res.operation = GET;
          res.ok = false;
          _completionResponse = _createCompletionResponse(res);
            
        } else {
            
          res.localResponse = true;
          res.operation = GET;
          res.ok = true;
          res.payload = new JsonObject.fromMap(document['payload']);
          _completionResponse = _createCompletionResponse(res);
          
        }
         
        _clientCompleter();
        
        
    } else {
      
        void completer(){
      
          /* If Ok update local storage with the document */
         
          JsonObject res = _database.wilt.completionResponse;
          if ( !res.error ) {
        
            JsonObject successResponse = res.jsonCouchResponse;
            _updateLocalStorageObject(id,
                             successResponse,
                            _UPDATED);
            res.localResponse = false;
            res.operation = GET;
            res.ok = true;
            res.payload = successResponse;
            _completionResponse = _createCompletionResponse(res);     
            
          } else {
            
            res.localResponse = false;
            res.operation = GET;
            res.ok = false;
            _completionResponse = _createCompletionResponse(res);
            
          }
          
          _clientCompleter();
          
        };
        
        /* Get the document from CouchDb */
        _database.wilt.resultCompletion = completer;
        _database.wilt.getDocument(id, rev:rev);
        
    }
    
      
  }
  
  /**
   * Delete a document
   */
   void delete(String id,
               [String rev = null]) {
     
     /* Always delete from local storage if the key exists */
     bool exists = _deleteLocalStorageObject(id);
     if ( ! exists ) {
       
       JsonObject res = new JsonObject();
       res.localResponse = true;
       res.operation = DELETE;
       res.ok = false;
       _completionResponse = _createCompletionResponse(res);
       _clientCompleter();
       return;
     }
     
     /* Check for offline, if so add to the pending delete queue and return */
     if ( !_online ) {
       
       _database.addPendingDelete(id);
       JsonObject res = new JsonObject();
       res.localResponse = true;
       res.operation = DELETE;
       res.ok = true;
       _completionResponse = _createCompletionResponse(res);
       _clientCompleter();      
       return;
       
     }
     
     /* Online, delete from CouchDb */
     void completer(){
       
       /* If not OK add to the pending delete queue for later */    
       JsonObject res = _database.wilt.completionResponse;
       if ( res.error ) {
         
         _database.addPendingDelete(id);        
         res.localResponse = false;
         res.operation = DELETE;
         res.ok = false;
         _completionResponse = _createCompletionResponse(res);
         
       } else {
         
         res.localResponse = false;
         res.operation = DELETE;
         res.ok = false;
         _completionResponse = _createCompletionResponse(res);
                 
       }
       
       _clientCompleter();
       
     };
     
     /* Delete the document from CouchDb */
     _database.wilt.resultCompletion = completer;
     _database.wilt.deleteDocument(id, rev);   
     
   }
}
