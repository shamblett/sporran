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
  static final _ATTACHMENTMARKER = "sporranAttachment";
  
  static final PUT = "put";
  static final GET = "get";
  static final DELETE = "delete";
  static final PUT_ATTACHMENT = "put_attachment";
  static final GET_ATTACHMENT = "get_attachment";
  static final DELETE_ATTACHMENT = "delete_attachment";
  
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
   * Lawndart database
   */
  Store get lawndart => _database.lawndart;
  
  /**
   * Lawndart databse is open
   */
  bool get lawnIsOpen => _database.lawnIsOpen;
  
  /**
   * Wilt database
   */
  Wilt get wilt => _database.wilt;
  
  /**
   * On/Offline indicator
   */
  bool _online = true;
  bool get online {
    
    /* If we are not online or the CouchDb database is not 
     * available we are offline
     */
    if ( (!_online) || (_database.noCouchDb) ) return false;
    return true;
    
  }
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
   * Ready event
   */
  Stream get onReady => _database.onReady;
  
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
     
     /**
      * Online/offline listeners
      */
      window.onOnline.listen((_) => _online = true);
      window.onOffline.listen((_) => _online = false);
     
  }
  
  
  /**
   * Common completion response creator for all databases
   */
  JsonObject _createCompletionResponse(JsonObject result) {
    
    JsonObject completion = new JsonObject();
    
    completion.operation = result.operation;
    completion.payload = result.payload;
    completion.localResponse = result.localResponse;
    
    /**
     * Check for a local or Wilt response 
     */
    if ( result.localResponse ) {
       
      completion.ok = result.ok;
      completion.id = result.id;
      
    } else {
      
      if ( result.error ) {
        
        completion.ok = false;
        completion.errorCode = result.errorCode;
        completion.errorText = result.jsonCouchResponse.error;
        completion.errorReason = result.jsonCouchResponse.reason;
        
      } else {
        
        completion.ok = true;
        completion.payload = result.payload;
        
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
  Future<JsonObject> _getLocalStorageObject(String key) {
    
    JsonObject localObject = new JsonObject();
    var completer = new Completer();
    
    /**
     * Try Lawndart first then the hot cache
     */
    _database.lawndart.getByKey(key).then((document) {
      
      JsonObject res = new JsonObject();
      
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
        if ( document != null) {
          
        localObject.payload = document['payload'];
       
        } 
      }
      
      completer.complete(localObject);
      
    });
    
    
    return completer.future; 
    
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
    if ( !online ) {
      
      JsonObject res = new JsonObject();
      res.localResponse = true;
      res.operation = PUT;
      res.ok = true;
      res.payload = null;
      res.id = id;
      _completionResponse = _createCompletionResponse(res);
      _clientCompleter();
      return;
      
    }
     
    /* Complete locally, then boomerang to the client */
    void completer() {
      
      /* If success, mark the update as UPDATED in local storage */
      JsonObject res = _database.wilt.completionResponse;
      res.ok = false;
      if ( !res.error) {
        
        _updateLocalStorageObject(id,
            document,
            _UPDATED);
        res.ok = true;
        
      }
      res.localResponse = false;
      res.operation = PUT;
      res.payload = res.jsonCouchResponse;
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
    if ( !online ) {
        
        _getLocalStorageObject(id)
          ..then((document) {
         
            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.operation = GET;
            res.id = id;
            if ( document == null ) {
                    
              res.ok = false;
              res.payload = null;
             _completionResponse = _createCompletionResponse(res);
            
            } else {
            
              res.ok = true;
              res.payload = new JsonObject.fromMap(document['payload']);
              _completionResponse = _createCompletionResponse(res);
          
            }
         
            _clientCompleter();
            
          });
        
        
    } else {
      
        void completer(){
      
          /* If Ok update local storage with the document */       
          JsonObject res = _database.wilt.completionResponse;
          if ( !res.error ) {
        
            _updateLocalStorageObject(id,
                            res.jsonCouchResponse,
                            _UPDATED);
            res.localResponse = false;
            res.operation = GET;
            res.ok = true;
            res.payload = res.jsonCouchResponse;
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
   * Delete a document.
   * 
   * Revision must be supplied if we are online
   */
   void delete(String id,
               [String rev = null]) {
     
     /* Remove from the hot cache */
     _database.remove(id);
     
     /* Remove from Lawndart */
     _database.lawndart.exists(id)
       ..then((bool exists) {
         
         if ( exists ) {
           
           _database.lawndart.removeByKey(id);
           
           /* Check for offline, if so add to the pending delete queue and return */
           if ( !online ) {
       
             _database.addPendingDelete(id);
             JsonObject res = new JsonObject();
             res.localResponse = true;
             res.operation = DELETE;
             res.ok = true; 
             res.id = id;
             res.payload = null;
             _completionResponse = _createCompletionResponse(res);
             _clientCompleter();      
             return;
              
           } else { 
       
              /* Online, delete from CouchDb */
              void completer() {
                
                JsonObject res = _database.wilt.completionResponse;
                res.operation = DELETE;
                res.localResponse = false;
                res.payload = res.jsonCouchResponse;
                if ( !res.error ) {
                    
                  res.ok = false; 
                  _database.removePendingDelete(id);
                  
                } else {
                  
                  res.ok = true;
                  
                }
                
               _completionResponse = _createCompletionResponse(res);
               _clientCompleter();
       
            };
     
            /* Delete the document from CouchDb */
            _database.wilt.resultCompletion = completer;
            _database.wilt.deleteDocument(id, rev); 
            
           }
           
         } else {
           
           /* Doesnt exist, return error */
           JsonObject res = new JsonObject();
           res.localResponse = true;
           res.operation = DELETE;
           res.ok = false;
           res.id = id;
           _completionResponse = _createCompletionResponse(res);
           _clientCompleter();
           
         }
         
      });
  }
   
  /**
   * Put attachment
   * 
   * If the revision is supplied the attachment to the document will be updated, 
   * otherwise the attachment will be created, along with the document if needed.
   * 
   * The JsonObject attachment parameter must contain the following :-
   * 
   * String attachmentName
   * String rev - maybe '', see above
   * String contentType - mime type in the form 'image/png'
   * String payload - stringified binary blob
   */
   void putAttachment(String id,
                      JsonObject attachment) {
     
     
     /* Update LawnDart */
     String key = "$id-${attachment.attachmentName}-$_ATTACHMENTMARKER";
     _updateLocalStorageObject(key,
         attachment,
         _NOT_UPDATED);
     
     
     /* If we are offline just return */
     if ( !online ) {
       
       JsonObject res = new JsonObject();
       res.localResponse = true;
       res.operation = PUT_ATTACHMENT;
       res.ok = true;
       _completionResponse = _createCompletionResponse(res);
       _clientCompleter();
       return;
       
     }
     
     /* Complete locally, then boomerang to the client */
     void completer() {
       
       /* If success, mark the update as UPDATED in local storage */
       JsonObject res = _database.wilt.completionResponse;
       res.ok = false;
       if ( !res.error) {
         
         _updateLocalStorageObject(key,
             attachment,
             _UPDATED);
         res.ok = true;
         
       }
       res.localResponse = false;
       res.operation = PUT_ATTACHMENT;
       res.payload = res.jsonCouchResponse;
       _completionResponse = _createCompletionResponse(res);
       _clientCompleter();
       
     };

     /* Do the create */
     _database.wilt.completionResponse;
     _database.wilt.resultCompletion = completer;
     if ( attachment.rev == '' ) {
     
       _database.wilt.createAttachment(id, 
                                       attachment.attachmentName, 
                                       attachment.rev, 
                                       attachment.contentType, 
                                       attachment.payload);
     
     } else {
       
       _database.wilt.updateAttachment(id, 
           attachment.attachmentName, 
           attachment.rev, 
           attachment.contentType, 
           attachment.payload);
       
     }
     
   }
   
   /**
    * Delete an attachment
    */
   void deleteAttachment(String id,
                         String attachmentName,
                         String rev) { 
     
     String key = "$id-$attachmentName-$_ATTACHMENTMARKER";
     
     /* Remove from the hot cache */
     _database.remove(key);
     
     /* Remove from Lawndart */
     _database.lawndart.exists(key)
       ..then((bool exists) {
         
         JsonObject res = _database.wilt.completionResponse;
         
         if ( exists ) {
           
           _database.lawndart.removeByKey(key);
           
           /* Check for offline, if so add to the pending delete queue and return */
           if ( !online ) {
       
             _database.addPendingDelete(key);
              res.localResponse = true;
              res.operation = DELETE_ATTACHMENT;
              res.ok = true;
              _completionResponse = _createCompletionResponse(res);
              _clientCompleter();      
              return;
              
           } else { 
       
              /* Online, delete from CouchDb */
              void completer() {
                
                res.localResponse = false;
                res.operation = DELETE_ATTACHMENT;
                res.ok = false;
                if ( !res.error ) res.ok = true;
               
               _completionResponse = _createCompletionResponse(res);
               _clientCompleter();
       
            };
     
            /* Delete the document from CouchDb */
            _database.wilt.resultCompletion = completer;
            _database.wilt.deleteAttachment(id, 
                                            attachmentName,
                                            rev); 
            
           }
           
         } else {
           
           /* Doesnt exists, return error */
           res.localResponse = false;
           res.operation = DELETE_ATTACHMENT;
           res.ok = false;
           _completionResponse = _createCompletionResponse(res);
           _clientCompleter();
           
         }
         
      });  
     
   }
   
   /**
    * Get an attachment
    */
   void getAttachment(String id,
                      String attachmentName) {
     
     String key = "$id-$attachmentName-$_ATTACHMENTMARKER";
     
     /* Check for offline, if so try the get from local storage */
     if ( !online ) {
       
       _getLocalStorageObject(key)
       ..then((document) {
       
          JsonObject res = new JsonObject();
          if ( document == null ) {
         
            res.localResponse = true;
            res.operation = GET_ATTACHMENT;
            res.ok = false;
            _completionResponse = _createCompletionResponse(res);
         
          } else {
         
            res.localResponse = true;
            res.operation = GET_ATTACHMENT;
            res.ok = true;
            res.payload = new JsonObject.fromMap(document['payload']);
            _completionResponse = _createCompletionResponse(res);
         
          }
       
          _clientCompleter();
          
       });
          
     } else {
       
       void completer(){
         
         /* If Ok update local storage with the attachment */   
         JsonObject res = _database.wilt.completionResponse;
         if ( !res.error ) {
           
           JsonObject successResponse = res.jsonCouchResponse;
           res.localResponse = false;
           res.operation = GET_ATTACHMENT;
           res.ok = true;
           JsonObject attachment = new JsonObject();
           attachment.attachmentName = attachmentName;
           attachment.rev = successResponse.rev;
           attachment.contentType = successResponse.contentType;
           attachment.payload = res.responseText;
           res.payload = attachment;
           _completionResponse = _createCompletionResponse(res);  
           _updateLocalStorageObject(key,
               attachment,
               _UPDATED);
           
         } else {
           
           res.localResponse = false;
           res.operation = GET_ATTACHMENT;
           res.ok = false;
           _completionResponse = _createCompletionResponse(res);
           
         }
         
         _clientCompleter();
         
       };
       
       /* Get the attachment from CouchDb */
       _database.wilt.resultCompletion = completer;
       _database.wilt.getAttachment(id,
                                    attachmentName);
       
     }
     
     
   }
   
   
   
}
