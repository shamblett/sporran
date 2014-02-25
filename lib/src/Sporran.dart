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
  static final PUT = "put";
  static final GET = "get";
  static final DELETE = "delete";
  static final PUT_ATTACHMENT = "put_attachment";
  static final GET_ATTACHMENT = "get_attachment";
  static final DELETE_ATTACHMENT = "delete_attachment";
  static final BULK_CREATE ="bulk_create";
  static final GET_ALL_DOCS ="get_all_docs";
  static final DB_INFO ="db_info";
  
  
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
    
    /* If we are not online or we are and the CouchDb database is not 
     * available we are offline
     */
    if ( (!_online) || (_database.noCouchDb) ) return false;
    return true;
    
  }
  set online(bool state) {
    
    _online = state;
    if ( state ) _transitionToOnline();
    
  }
  
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
   * Manual notification control 
   */
  bool get manualNotificationControl => _database.manualNotificationControl;
  
  /**
   * Start change notification manually
   */
  void startChangeNotifications() {
      
      if ( manualNotificationControl ) {
        
       if ( _database.wilt.changeNotificationsPaused ) {
        
         _database.wilt.restartChangeNotifications();
         
       } else {
         
         _database.startChangeNotifications();
       }
        
      }
  }
  
  /**
   * Stop change notification manually
   */
  void stopChangeNotifications() {
      
      if ( manualNotificationControl )
      _database.wilt.pauseChangeNotifications();
  }
  
  /**
   * Construction.
   * 
   */
  Sporran(this._dbName,
          String hostName,
          [bool manualNotificationControl = false,
           String port = "5984",
           String scheme = "http://",
           String userName = null,
           String password = null]) {
    
    
    /**
     * Construct our database.
     */    
     _database = new _SporranDatabase(_dbName,
                                       hostName,
                                       manualNotificationControl,
                                       port,
                                       scheme,
                                       userName,
                                       password);   
     
     /**
      * Online/offline listeners
      */
      window.onOnline.listen((_) => _transitionToOnline());
      window.onOffline.listen((_) => _online = false);
     
  }
  
  /**
   * Online transition 
   */
  void _transitionToOnline() {
    
    _online = true;
    
    /**
     * If we have never connected to CouchDb try now,
     * otherwise we can sync straight away
     */
    if ( _database.noCouchDb ) {
      
      _database.connectToCouch(true);
      
    } else {
      
      sync();
    
    }
    
  }
  
  /**
   * Common completion response creator for all databases
   */
  JsonObject _createCompletionResponse(JsonObject result) {
    
    JsonObject completion = new JsonObject();
    
    completion.operation = result.operation;
    completion.payload = result.payload;
    completion.localResponse = result.localResponse;
    completion.id = result.id;
    completion.rev = result.rev;
    
    /**
     * Check for a local or Wilt response 
     */
    if ( result.localResponse ) {
       
      completion.ok = result.ok;
     
      
    } else {
      
      if ( result.error ) {
        
        completion.ok = false;
        completion.errorCode = result.errorCode;
        completion.errorText = result.jsonCouchResponse.error;
        completion.errorReason = result.jsonCouchResponse.reason;
        
      } else {
        
        completion.ok = true;
        
      }
      
    }
    
    return completion;
      
  }
  
  
  /**
   * Update document.
   * 
   * If the document does not exist a create is performed.
   * 
   * For an upadte operation a specific revision must be specified.
   */
  void put(String id,
           JsonObject document,
           [String rev = null]){
    
    /* Update LawnDart */
    _database.updateLocalStorageObject(id,
                    document,
                    _SporranDatabase.NOT_UPDATED);
    
    
    /* If we are offline just return */
    if ( !online ) {
      
      JsonObject res = new JsonObject();
      res.localResponse = true;
      res.operation = PUT;
      res.ok = true;
      res.payload = document;
      res.id = id;
      res.rev = null;
      _completionResponse = _createCompletionResponse(res);
      _clientCompleter();
      return;
      
    }
     
    /* Complete locally, then boomerang to the client */
    void completer() {
      
      /* If success, mark the update as UPDATED in local storage */
      JsonObject res = _database.wilt.completionResponse;
      res.ok = false;
      res.localResponse = false;
      res.operation = PUT;
      res.id = id;
      res.payload = document;
      if ( !res.error) {
        
        _database.updateLocalStorageObject(id,
            document,
            _SporranDatabase.UPDATED);
        
        res.ok = true;
       
        res.rev = res.jsonCouchResponse.rev;
        
      } else {
      
        res.rev = null;
        
      }
      
      _completionResponse = _createCompletionResponse(res);
      _clientCompleter();
      
    };

    /* Do the put */
    _database.wilt.completionResponse;
    _database.wilt.resultCompletion = completer;
    _database.wilt.putDocument(id, 
                               document,
                               rev);
    
  }
  
  /**
   * Get a document 
   */
  void get(String id,
           [String rev = null]) {
    
    
    /* Check for offline, if so try the get from local storage */
    if ( !online ) {
        
        _database.getLocalStorageObject(id)
          ..then((document) {
         
            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.operation = GET;
            res.id = id;
            res.rev = null;
            if ( document == null ) {
                    
              res.ok = false;
              res.payload = null;
            
            } else {
            
              res.ok = true;
              res.payload = new JsonObject.fromMap(document['payload']);
          
            }
         
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
            
          });
        
        
    } else {
      
        void completer(){
      
          /* If Ok update local storage with the document */       
          JsonObject res = _database.wilt.completionResponse;
          res.operation = GET;
          res.id = id;
          res.localResponse = false;
          if ( !res.error ) {
        
            _database.updateLocalStorageObject(id,
                            res.jsonCouchResponse,
                            _SporranDatabase.UPDATED);  
            res.ok = true;
            res.rev = WiltUserUtils.getDocumentRev(res.jsonCouchResponse);
            res.payload = res.jsonCouchResponse;           
            
          } else {
            
            res.ok = false;
            res.payload = null;
            res.rev = null;
            
          }
          
          _completionResponse = _createCompletionResponse(res);
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
    
     
     /* Remove from Lawndart */
     _database.lawndart.getByKey(id)..
     then((document) {
         
         if ( document != null) {
           
           /* Remove from the hot cache */
           _database.remove(id);
              
             JsonObject deletedDocument = new JsonObject.fromMap(document['payload']);
             _database.lawndart.removeByKey(id)..
             then((_) {
               
               /* Check for offline, if so add to the pending delete queue and return */
               if ( !online ) {
                 
                 _database.addPendingDelete(id, deletedDocument);
                 JsonObject res = new JsonObject();
                 res.localResponse = true;
                 res.operation = DELETE;
                 res.ok = true; 
                 res.id = id;
                 res.payload = null;
                 res.rev = null;
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
                   res.id = id;
                   res.rev = res.jsonCouchResponse.rev;
                   if ( res.error ) {
                     
                     res.ok = false; 
                     
                   } else {
                     
                     res.ok = true;
                     
                   }
                   
                   _completionResponse = _createCompletionResponse(res);
                   _clientCompleter();
                   
                 }
                 
                 /* Delete the document from CouchDb */
                 _database.wilt.resultCompletion = completer;
                 _database.wilt.deleteDocument(id, rev); 
                 
               }
                     
           });
           
         } else {
           
           /* Doesnt exist, return error */
           JsonObject res = new JsonObject();
           res.localResponse = true;
           res.operation = DELETE;
           /* Try the hot cache */
           JsonObject document = _database.get(id);
           res.ok = false;
           if ( document != null ) { 
              
             res.ok = true;
            /* Remove from the hot cache */
            _database.remove(id);
            /* Try Lawn again but don't check for a response */
            _database.lawndart.removeByKey(id);
            /* Pending delete if offline */
            if ( !online ) _database.addPendingDelete(id, document);
            
           }
           res.id = id;
           res.payload = null;
           res.rev = null;
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
     String key = "$id-${attachment.attachmentName}-${_SporranDatabase.ATTACHMENTMARKER}";
     _database.updateLocalStorageObject(key,
         attachment,
         _SporranDatabase.NOT_UPDATED);
     
     
     /* If we are offline just return */
     if ( !online ) {
       
       JsonObject res = new JsonObject();
       res.localResponse = true;
       res.operation = PUT_ATTACHMENT;
       res.ok = true;
       res.payload = attachment;
       res.id = id;
       res.rev = null;
       _completionResponse = _createCompletionResponse(res);
       _clientCompleter();
       return;
       
     }
     
     /* Complete locally, then boomerang to the client */
     void completer() {
       
       /* If success, mark the update as UPDATED in local storage */
       JsonObject res = _database.wilt.completionResponse;
       res.ok = false;
       res.localResponse = false;
       res.id = id;
       res.operation = PUT_ATTACHMENT;
       res.rev = null;
       res.payload = null;
      
       if ( !res.error) {
         
         JsonObject newAttachment = new JsonObject.fromMap(attachment); 
         newAttachment.contentType = attachment.contentType;
         newAttachment.payload = attachment.payload;
         newAttachment.attachmentName = attachment.attachmentName;
         res.payload = newAttachment;  
         res.rev = res.jsonCouchResponse.rev;
         newAttachment.rev = res.jsonCouchResponse.rev;
         _database.updateLocalStorageObject(key,
             newAttachment,
             _SporranDatabase.UPDATED);
         res.ok = true;
         
       }
       _completionResponse = _createCompletionResponse(res);
       _clientCompleter();
       return;
       
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
    * Delete an attachment.
    * 
    * Revision can be null if offline
    */
   void deleteAttachment(String id,
                         String attachmentName,
                         String rev) { 
     
     String key = "$id-$attachmentName-${_SporranDatabase.ATTACHMENTMARKER}";
     
     /* Remove from Lawndart */
     _database.lawndart.getByKey(id)..
     then((document) {
         
         if ( document != null) {
           
           /* Remove from the hot cache */
           _database.remove(id);
              
             JsonObject deletedDocument = new JsonObject.fromMap(document['payload']);
             _database.lawndart.removeByKey(id)..
             then((_) {
               
               /* Check for offline, if so add to the pending delete queue and return */
               if ( !online ) {
                 
                 _database.addPendingDelete(id, deletedDocument);
                 JsonObject res = new JsonObject();
                 res.localResponse = true;
                 res.operation = DELETE_ATTACHMENT;
                 res.ok = true; 
                 res.id = id;
                 res.payload = null;
                 res.rev = null;
                 _completionResponse = _createCompletionResponse(res);
                 _clientCompleter();      
                 return;
                 
               } else { 
                 
                 /* Online, delete from CouchDb */
                 void completer() {
                   
                   JsonObject res = _database.wilt.completionResponse;
                   res.operation = DELETE_ATTACHMENT;
                   res.localResponse = false;
                   res.payload = res.jsonCouchResponse;
                   res.id = id;
                   res.rev = res.jsonCouchResponse.rev;
                   if ( res.error ) {
                     
                     res.ok = false; 
                     
                   } else {
                     
                     res.ok = true;
                     
                   }
                   
                   _completionResponse = _createCompletionResponse(res);
                   _clientCompleter();
                   
                 }
                 
                 /* Delete the document from CouchDb */
                 _database.wilt.resultCompletion = completer;
                 _database.wilt.deleteDocument(id, rev); 
                 
               }
                     
           });
           
         } else {
           
           /* Doesnt exist, return error */
           JsonObject res = new JsonObject();
           res.localResponse = true;
           res.operation = DELETE;
           /* Try the hot cache */
           JsonObject document = _database.get(id);
           res.ok = false;
           if ( document != null ) { 
              
             res.ok = true;
            /* Remove from the hot cache */
            _database.remove(id);
            /* Try Lawn again but don't check for a response */
            _database.lawndart.removeByKey(id);
            /* Pending delete if offline */
            if ( !online ) _database.addPendingDelete(id, document);
            
           }
           res.id = id;
           res.payload = null;
           res.rev = null;
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
     
     String key = "$id-$attachmentName-${_SporranDatabase.ATTACHMENTMARKER}";
     
     /* Check for offline, if so try the get from local storage */
     if ( !online ) {
       
       _database.getLocalStorageObject(key)
       ..then((document) {
       
          JsonObject res = new JsonObject();
          res.localResponse = true;
          res.id = id;
          res.rev = null;
          res.operation = GET_ATTACHMENT;
          if ( document == null ) {
           
            res.ok = false;
            res.payload = null;
           
          } else {
         
            res.ok = true; 
            res.payload = new JsonObject.fromMap(document['payload']);
         
          }
       
          _completionResponse = _createCompletionResponse(res);
          _clientCompleter();
          
       });
          
     } else {
       
       void completer(){
         
         /* If Ok update local storage with the attachment */   
         JsonObject res = _database.wilt.completionResponse;
         res.operation = GET_ATTACHMENT;
         res.id = id;
         res.localResponse = false; 
         res.rev = null;
         
         if ( !res.error ) {
           
           JsonObject successResponse = res.jsonCouchResponse;
            
           res.ok = true;       
           JsonObject attachment = new JsonObject();
           attachment.attachmentName = attachmentName;
           attachment.contentType = successResponse.contentType;
           attachment.payload = res.responseText;
           res.payload = attachment;
            
           _database.updateLocalStorageObject(key,
               attachment,
               _SporranDatabase.UPDATED);
           
         } else {
           
           res.ok = false;
           res.payload = null;
           
         }
         
         _completionResponse = _createCompletionResponse(res);
         _clientCompleter();
         
       };
       
       /* Get the attachment from CouchDb */
       _database.wilt.resultCompletion = completer;
       _database.wilt.getAttachment(id,
                                    attachmentName);
       
     }
     
     
   }
   
   /**
    * Bulk document create.
    * 
    * docList is a map of documents with their keys
    */
   void bulkCreate(Map<String, JsonObject> docList) {
     
     
     /* Update LawnDart */
     docList.forEach((key, document) {
 
      _database.updateLocalStorageObject(key,
           document,
           _SporranDatabase.NOT_UPDATED);
     });
     
     /* If we are offline just return */
     if ( !online ) {
       
       JsonObject res = new JsonObject();
       res.localResponse = true;
       res.operation = BULK_CREATE;
       res.ok = true;
       res.payload = docList;
       res.id = null;
       res.rev = null;
       _completionResponse = _createCompletionResponse(res);
       _clientCompleter();
       return;
       
     }
     
     /* Complete locally, then boomerang to the client */
     void completer() {
       
       /* If success, mark the update as UPDATED in local storage */
       JsonObject res = _database.wilt.completionResponse;
       res.ok = false;
       res.localResponse = false;
       res.operation = BULK_CREATE;
       res.id = null;
       res.payload = docList;
       res.rev = null;
       if ( !res.error) {
         
         docList.forEach((key, document) {
           
           _database.updateLocalStorageObject(key,
               document,
               _SporranDatabase.UPDATED);
         });
         
         List revisions = new List<String>();
         JsonObject couchResp = res.jsonCouchResponse;
         couchResp.forEach((resp){
           
           /* Try this, there may be an error, if so there is no
            * revision
            */
           try{
            revisions.add(resp.rev);
           } catch(e) {
            revisions.add(null); 
           }
           
         });
         res.rev = revisions;
         res.ok = true;
               
       } 
       
       _completionResponse = _createCompletionResponse(res);
       _clientCompleter();
       
     };

     /* Prepare the documents */
     List documentList = new List<String>();
     docList.forEach((key, document) {
       
       String docString = WiltUserUtils.addDocumentId(document,
                                                      key); 
       documentList.add(docString);
       
     });
     
     String docs = WiltUserUtils.createBulkInsertString(documentList);
        
     /* Do the bulk create*/
     _database.wilt.completionResponse;
     _database.wilt.resultCompletion = completer;
     _database.wilt.bulkString(docs);
     
     
   }
   
   /**
    * Get all documents.
    * 
    * The parameters should be self explanatory and are addative.
    *
    * In offline mode only the keys parameter is respected. 
    * The includeDocs parameter is also forced to true.
    */
   void getAllDocs({bool includeDocs:false,
     int limit:null,
     String startKey:null,
     String endKey:null,
     List<String> keys:null,
     bool descending:false}) {
     
     
     /* Check for offline, if so try the get from local storage */
     if ( !online ) {
       
       _database.getLocalStorageObjects(keys)   
       ..then((documents) {
         
         JsonObject res = new JsonObject();
         res.localResponse = true;
         res.operation = GET_ALL_DOCS;
         res.id = null;
         res.rev = null;
         if ( documents == null ) {
           
           res.ok = false;
           res.payload = null;
           
         } else {
           
           res.ok = true;
           res.payload = documents;
           
         }
         
         _completionResponse = _createCompletionResponse(res);
         _clientCompleter();
         
       });
       
       
     } else {
       
       void completer(){
         
         /* If Ok update local storage with the document */       
         JsonObject res = _database.wilt.completionResponse;
         res.operation = GET_ALL_DOCS;
         res.id = null;
         res.rev = null;
         res.localResponse = false;  
         if ( !res.error ) {
                     
           res.ok = true;
           res.payload = res.jsonCouchResponse;
           
           
         } else {
           
           res.localResponse = false;
           res.ok = false;
           res.payload = null;
          
           
         }
         
         _completionResponse = _createCompletionResponse(res);  
         _clientCompleter();
         
       };
       
       /* Get the document from CouchDb */
       _database.wilt.resultCompletion = completer;
       _database.wilt.getAllDocs(includeDocs:includeDocs,
                                 limit:limit,
                                 startKey:startKey,
                                 endKey:endKey,
                                 keys:keys,
                                 descending:descending);
       
     }
   
   }
   
   /**
    * Get information about the database.
    * 
    * When offline the a list of the keys in the Lawndart database are returned, 
    * otherwise a response for CouchDb is returned.
    */
   void getDatabaseInfo() {
     
     if ( !online ) {
       
       _database.lawndart.keys().toList()
       ..then((List keys) {
         
         JsonObject res = new JsonObject();
         res.localResponse = true;
         res.operation = DB_INFO;
         res.id = null;
         res.rev = null;
         res.payload = keys;
         res.ok = true;
         _completionResponse = _createCompletionResponse(res);  
         _clientCompleter();
         return;
         
       });
       
     } else {
       
       
       void completer(){
         
         /* If Ok update local storage with the database info */       
         JsonObject res = _database.wilt.completionResponse;
         res.operation = DB_INFO;
         res.id = null;
         res.rev = null;
         res.localResponse = false;  
         if ( !res.error ) {
                     
           res.ok = true;
           res.payload = res.jsonCouchResponse;
           
           
         } else {
           
           res.localResponse = false;
           res.ok = false;
           res.payload = null;
               
         }
         
         _completionResponse = _createCompletionResponse(res);  
         _clientCompleter();
         
       };
       
       /* Get the database information from CouchDb */
       _database.wilt.resultCompletion = completer;
       _database.wilt.getDatabaseInfo();
       
     }
       
   }
   
   /**
    * Synchronise local storage and CouchDb when we come online or on demand.
    * 
    * Note we don't check for failures in this, there is nothing we can really do
    * if we say get a conflict error or a not exists error on an update or delete.
    * 
    * For updates, if applied successfully we wait for the change notification to
    * arrive to mark the update as UPDATED. Note if these are switched off sync may be
    * lost with Couch.
    */
   void sync() {
     
     
     /* Only if we are online */
     if ( !online ) return;
     
     _database.sync();
     
  }
   
}
