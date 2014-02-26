/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 * 
 * 
 * A Sporran database comprises of a Wilt object, a Lawndart object and an in memory hot cache in tandem,
 * all sharing the same database name. 
 */

part of sporran;

class _SporranDatabase {
  
  /**
   * Constants
   */
  static final NOT_UPDATED = "not_updated";
  static final UPDATED = "updated";
  static final ATTACHMENTMARKER = "sporranAttachment";
  
  /** 
   * Host name
   */
  String _host = null;  
  String get host => _host;
  
  /** 
   * Port number
   */
  String _port = null; 
  String get port => _port;
  
  /** 
   * HTTP scheme
   */
  String _scheme = null; 
  String get scheme => _scheme;
  
  /**
   *  Authentication, user name
   */
  String _user = null; 
  /**
   *  Authentication, user password
   */
  String _password = null;   
  
  /**
   * Manual notification control 
   */
  bool _manualNotificationControl = false;
  bool get manualNotificationControl => _manualNotificationControl;
  
  /**
   * The Wilt database
   */
  Wilt _wilt;
  Wilt get wilt => _wilt;
  
  /**
   * The Lawndart database
   */
  Store _lawndart;
  Store get lawndart => _lawndart;
  
  /**
   * Database name
   */
  String _dbName;
  String get dbName => _dbName;
  
  /**
   * CouchDb database is intact
   */
  bool _noCouchDb = true;
  bool get noCouchDb => _noCouchDb;
  
  /**
   * In memory hot cache
   */
  Map _hotCache = new Map<String, JsonObject>();
  
  /**
   * Pending delete queue
   */
  Map _pendingDeletes = new Map<String, JsonObject>();
  Map get pendingDeletes => _pendingDeletes;
  
  /**
   * Lawndart open indication
   */
  bool get lawnIsOpen => _lawndart.isOpen;
  
  /**
   * Event stream for Ready events
   */
  final _onReady = new StreamController.broadcast();
  Stream get onReady => _onReady.stream;
  
  
  /**
   * Construction, for Wilt we need URL and authentication parameters.
   * For LawnDart only the database name, the store name is fixed by Sporran
   */
  _SporranDatabase(this._dbName,
                   this._host,
                  [this._manualNotificationControl = false,
                   this._port = "5984",
                   this._scheme = "http://",
                   this._user = null,
                   this._password = null]) {
    
    
    /**
     * Instantiate a Store object
     */
    _lawndart = new Store(this._dbName,
                          "Sporran");
    
    /**
     * Open it, don't worry about waiting
     */
    
    _lawndart.open()
      ..then((_) => _lawndart.nuke());
    
    /**
     * Instantiate a Wilt object
     */
    _wilt = new Wilt(_host,
                     _port,
                     _scheme);
    /**
     * Login
     */
    if ( _user != null ) {
      
      _wilt.login(_user,
                  _password);
      
    }
    
   /*
    * Open CouchDb
    */
    connectToCouch();
    
  }
  
  
  /**
   * Start change notifications
   */
 startChangeNotifications() {
    
    WiltChangeNotificationParameters parameters = new WiltChangeNotificationParameters();
    parameters.includeDocs = true;
   _wilt.startChangeNotification(parameters);
   
   /* Listen for and process changes */
   _wilt.changeNotification.listen((e) {
     
     _processChange(e);
     
   });
    
  }
  
  /**
   * Change notification processor
   */
  _processChange(WiltChangeNotificationEvent e) {
    
    
    /* Ignore error events */
    if ( !(e.type == WiltChangeNotificationEvent.UPDATE ||
           e.type == WiltChangeNotificationEvent.DELETE) ) return;
    
    /* Process the update or delete event */
    if ( e.type == WiltChangeNotificationEvent.UPDATE ) {
      
      print("CN::Update ${e.docId}");
      updateLocalStorageObject(e.docId,
                               e.document,
                               e.docRevision,
                               UPDATED);
      
      /* Now update the attachments */
      
      /* Get a list of attachments from the document */   
      List attachments = WiltUserUtils.getAttachments(e.document);
      List attachmentsToDelete = new List<String>();
       
      /* For all the keys... */  
      _lawndart.keys().listen((String key) {
     
        /* If an attachment... */
        List keyList = key.split('-');
        if ( (keyList.length == 3) &&
             (keyList[2] == ATTACHMENTMARKER) ) {
           
                /* ...for this document... */
                if ( e.docId == keyList[0]) {
            
                  /* ..potentially now deleted... */
                  attachmentsToDelete.add(key);
              
                  /* ...check against all the documents current attachments */
                  attachments.forEach((attachment) {
                
                      if ( (keyList[1] == attachment.name) &&
                           (keyList[0] == e.docId ) &&
                           (keyList[2] == ATTACHMENTMARKER) ) {
                      
                              /* If still valid remove it from the delete list */
                              attachmentsToDelete.remove(key);
                          
                      }
            
                  }); 
              
               }
                
          }
        
        }, onDone:() {
          
          /* We now have a list of attachments for this document that 
          * are not present in the document itself so remove them.
          */
          attachmentsToDelete.forEach((key) {
          
            _lawndart.removeByKey(key)
              ..then((key) => remove(key));
          
            removePendingDelete(key);
          
          });
          
        });
        
      
      /* Now update already existing ones and add any new ones */
      updateDocumentAttachments(e.docId,
                                e.document);
      
    } else {
      
      print("CN::Delete ${e.docId}");
      /* Tidy up any pending deletes */
      removePendingDelete(e.docId);
      
      /* Do the delete */
      _lawndart.removeByKey(e.docId)
      ..then((key) =>  remove(e.docId));
      
      /* Remove all document attachments */
      _lawndart.keys().listen((String key) {
        
        List keyList = key.split('-');
        if ( (keyList.length == 3) &&
             (keyList[2] == ATTACHMENTMARKER) ) {
            
            _lawndart.removeByKey(key)
              ..then((key) => remove(key));
        } 
        
      });
       
    }
    
  }
  
  /**
   * Signal we are ready 
   */
  void _signalReady() {
   
    Event e = new Event.eventType('Event', 'SporranReady');
    _onReady.add(e);
    
  }
  
  /**
   * Create and/or connect to CouchDb
   */
 void connectToCouch([bool transitionToOnline = false]) {
      
    /**
     * If the CouchDb database does not exist create it.
     */
    void createCompleter() {
      
      
      JsonObject res = _wilt.completionResponse;
      if ( !res.error ) {
      
        _wilt.db = _dbName;
        _noCouchDb = false;
        
      } else {
        
        _noCouchDb = true;
        
      }
      
      /**
       * Start change notifications 
       */
      if ( !manualNotificationControl ) startChangeNotifications();
      
      /**
       * If this is a transition to online start syncing
       */
      if ( transitionToOnline ) sync();
      
      /**
       * Signal we are ready
       */
      _signalReady();
      
      
    };
    
    void allCompleter(){
      
      JsonObject res = _wilt.completionResponse;
      if ( !res.error ) {
        
        JsonObject successResponse = res.jsonCouchResponse;
        bool created = successResponse.contains(_dbName);
        if ( created == false ) {
          
          _wilt.resultCompletion = createCompleter;
          _wilt.createDatabase(_dbName);
          
        } else {
          
          _wilt.db = _dbName;
          _noCouchDb = false;
          
          /**
           * Start change notifications 
           */
          if ( !manualNotificationControl ) startChangeNotifications();
          
          /**
           * If this is a transition to online start syncing
           */
          if ( transitionToOnline ) sync();
          
          /**
          * Signal we are ready
          */
          _signalReady();
          
        }
        
      } else {
        
        _noCouchDb = true;
        _signalReady();
        
      }
      
    };
    
   _wilt.resultCompletion = allCompleter;
   _wilt.getAllDbs();
    
    
  }
  
  /**
   * Hot cache get
   */
  JsonObject get(String id) {
    
    if ( _hotCache.containsKey(id)) {
      
      return _hotCache[id];
    }
    
    return null;
    
  }
  
  /**
   * Hot cache put
   */
  void put(String id,
           JsonObject payload) {
    
    _hotCache[id] = payload;
    
    
  }
  
  /**
   * Hot cache remove
   */
  void remove(String id) {
    
    
    if ( _hotCache.containsKey(id)) {
      
      _hotCache.remove(id);
      
    }    
    
  }
  
  /**
   * Hot cache length
   */
  int length() {
    
    return _hotCache.length;
    
  }
  
  /**
   * Add a key to the pending delete queue
   */
  void addPendingDelete(String key,
                        Map document) {
    
    JsonObject deletedDocument = new JsonObject.fromMap(document);
    _pendingDeletes[key] = deletedDocument;
    
  }
  
  /**
   * Remove a key from the pending delete queue
   */
  void removePendingDelete(String key) {
    
    
    if ( _pendingDeletes.containsKey(key) ) _pendingDeletes.remove(key);
    
    
  }
  
  /*
   * Length of the pending delete queue
   */
  int pendingLength() {
    
    
    return _pendingDeletes.length;
    
  }
  
 /**
  * Update document attachments 
  */
  void updateDocumentAttachments(String id,
                                 JsonObject document) {
    
    /* Get a list of attachments from the document */   
    List attachments = WiltUserUtils.getAttachments(document);
    
    /* Exit if none */
    if ( attachments.length == 0 ) return;
    
    /* Create our own Wilt instance */
    Wilt wilting = new Wilt(_host, 
                            _port,
                            _scheme);
   
   /* Login if we are using authentication */
    if ( _user != null ) {
      
      wilting.login(_user,
                    _password);
    }
    
      
    /* Get and update all the attachments */
    attachments.forEach((attachment) {
      
      
      void completer() {
        
        JsonObject res = wilting.completionResponse;
        if ( !res.error ) {
          
          JsonObject successResponse = res.jsonCouchResponse;
          JsonObject newAttachment = new JsonObject();
          newAttachment.attachmentName = attachment.name;
          newAttachment.rev = WiltUserUtils.getDocumentRev(document);
          newAttachment.contentType = successResponse.contentType;
          newAttachment.payload = res.responseText;
          String key = "$id-${attachment.name}-${_SporranDatabase.ATTACHMENTMARKER}";
          updateLocalStorageObject(key,
              newAttachment,
              newAttachment.rev,
              _SporranDatabase.UPDATED);
          
        }
        
      }
      
      /* Get the attachment */
      wilting.db = _dbName;
      wilting.resultCompletion = completer;
      wilting.getAttachment(id, 
                            attachment.name);
        
    });
    
  }
  
  /**
   * Create local storage updated entry 
   */
  JsonObject _createUpdated(String key,
                            String revision,
                           JsonObject payload) {
    
    /* Add our type marker and set to 'not updated' */
    JsonObject update = new JsonObject();
    update.status = UPDATED;
    update.key = key;
    update.payload = payload;
    update.rev = revision;
    return update;
    
    
  }
  
  /**
   * Create local storage not updated entry
   */
  JsonObject _createNotUpdated(String key,
                               String revision,
                               JsonObject payload) {
    
    /* Add our type marker and set to 'not updated' */
    JsonObject update = new JsonObject();
    update.status = NOT_UPDATED;
    update.key = key;
    update.payload = payload;
    update.rev = revision;
    return update;
    
    
  }
  
  /**
   * Update local storage.
   * 
   * This will eventually become consistent, no need to wait on the future 
   * completion
   */
  void updateLocalStorageObject(String key,
                                JsonObject update,
                                String revision,
                                String updateStatus) {
    
    /* Check for not initialized */
    if ( (lawndart == null) || 
         (!lawndart.isOpen ) )
      throw new SporranException("Initialisation Failure, Lawndart is not initialized");
    
    
    /* Do the update */
    JsonObject localUpdate = new JsonObject();
    if ( updateStatus == NOT_UPDATED) {
      localUpdate = _createNotUpdated(key,
                                      revision,
                                      update);
    } else {
      localUpdate = _createUpdated(key,
                                   revision,
                                   update);
    }
    
    /**
     * Update the hot cache, then Lawndart.
     * When Lawndart has saved the item remove it from the
     * hot cache.
     */
    put(key, localUpdate);
    _lawndart.save(localUpdate, key)
    ..then((String key) {
      
      remove(key);
      
    });
  
  }
  

  /**
   * Get an object from local storage
   */
  Future<JsonObject> getLocalStorageObject(String key) {
    
    JsonObject localObject = new JsonObject();
    var completer = new Completer();
    
    /**
     * Try Lawndart first then the hot cache
     */
    lawndart.getByKey(key).then((document) {
      
      JsonObject res = new JsonObject();
      
      if ( document == null ) {
        
        /* Try the hot cache */
        JsonObject hotObject = get(key);
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
   * Get multiple objects from local storage
   */
  Future<Map<String,JsonObject>> getLocalStorageObjects(List<String> keys) {
    
    var completer = new Completer();
    Map results = new Map<String, JsonObject>();
    int keyPos = 0;
    
    /**
     * Try only Lawndart for objects
     */
    lawndart.getByKeys(keys).listen((value){
      
      JsonObject document = new JsonObject.fromMap(value);
      results[keys[keyPos]] = document;
      keyPos++;
      
    }, onDone:() {
      
      completer.complete(results);
      
    });
        
    return completer.future; 
    
  }
  
  /**
   * Delete a CouchDb document.
   * 
   * If this fails we probably have a conflict in which case
   * Couch wins.
   */
  void delete(String key,
              String revision) {
    
    
    /* Create our own Wilt instance */
    Wilt wilting = new Wilt(_host, 
                            _port,
                            _scheme);
   
   /* Login if we are using authentication */
    if ( _user != null ) {
      
      wilting.login(_user,
                    _password);
    }
    
    wilting.db = _dbName;
    wilting.resultCompletion = null;
    wilting.deleteDocument(key, 
                           revision);
    
  }
  
  /**
   * Delete a CouchDb attachment.
   * 
   * If this fails we probably have a conflict in which case
   * Couch wins.
   */
  void deleteAttachment(String key,
                        String name,
                        String revision) {
    
    
    /* Create our own Wilt instance */
    Wilt wilting = new Wilt(_host, 
                            _port,
                            _scheme);
   
   /* Login if we are using authentication */
    if ( _user != null ) {
      
      wilting.login(_user,
                    _password);
    }
    
    wilting.db = _dbName;
    wilting.resultCompletion = null;
    wilting.deleteAttachment(key,
                             name,
                             revision);
    
  }
  
  /**
   * Update/create a CouchDb attachment
   */
  void updateAttachment(String key,
                        String name,
                        String revision,
                        String contentType,
                        String payload) {
    
    
    /* Create our own Wilt instance */
    Wilt wilting = new Wilt(_host, 
                            _port,
                            _scheme);
   
   /* Login if we are using authentication */
    if ( _user != null ) {
      
      wilting.login(_user,
                    _password);
    }
    
    void getCompleter() {
      
      /**
       * If the document doesnt already have an attachment 
       * with this name get the revision and add this one.
       * We don't care about the outcome, if it errors there's
       * nothing we can do.
       */
      JsonObject res = wilting.completionResponse;
      if ( !res.error ) {
        
        JsonObject successResponse = res.jsonCouchResponse;
        List attachments = WiltUserUtils.getAttachments(successResponse);
        bool found = false;
        attachments.forEach((JsonObject attachment) {
          
          if ( attachment.name == name ) found = true;
          
        });
        
        if ( !found ) {
          
          String newRevision = WiltUserUtils.getDocumentRev(successResponse);
          wilting.resultCompletion = null;
          wilting.updateAttachment(key, 
              name, 
              newRevision, 
              contentType, 
              payload);
                 
        }
        
      }     
      
    }
    
    void putCompleter() {
      
      /**
       * If we have a conflict, get the document to get its
       * latest revision
       */
      JsonObject res = wilting.completionResponse;
      if ( res.error ) {
        
        if ( res.errorCode == 409 ) {
          
          wilting.resultCompletion = getCompleter;
          wilting.getDocument(key);
          
        }
        
      }
      
    }
    
    wilting.db = _dbName;
    wilting.resultCompletion = putCompleter;
    wilting.updateAttachment(key, 
                             name, 
                             revision, 
                             contentType, 
                             payload);
    
    
  }
  
  /**
   * Update/create a CouchDb document
   */
  Future<String> update(String key,
                 JsonObject document,
                 String revision) {
    
    
    Completer completer = new Completer();
    
    /* Create our own Wilt instance */
    Wilt wilting = new Wilt(_host, 
                            _port,
                            _scheme);
   
   /* Login if we are using authentication */
    if ( _user != null ) {
      
      wilting.login(_user,
                    _password);
    }
    
    void localCompleter() {
      
      JsonObject res = wilting.completionResponse;
      if ( !res.error ) {
        
        completer.complete(res.jsonCouchResponse.rev);
        
      }
      
    }
    wilting.db = _dbName;
    wilting.resultCompletion = localCompleter;
    wilting.putDocument(key, 
                        document,
                        revision);
    
    return completer.future;
    
  }
  
  /**
   * Manual bulk insert
   */
  Future<Map<String, String>> manualBulkInsert(Map<String, JsonObject> documentsToUpdate) {
    
    Completer completer = new Completer();
    Map revisions = new Map<String, String>();
    
    int length = documentsToUpdate.length;
    int count = 0;
    documentsToUpdate.forEach((String key, JsonObject document) {
      
      update(key,
             document.payload,
             document.rev)..
      then((String rev) {
     
        revisions[document.key] = rev;
        count++;
        if ( count == length ) completer.complete(revisions);
          
      });
      
    });
      
      return completer.future;
  }
    
  /**
   * Bulk insert documents
   */
  Future<JsonObject> bulkInsert(Map<String, JsonObject> docList) {
    
    var completer = new Completer();
    
    /* Create our own Wilt instance */
    Wilt wilting = new Wilt(_host, 
                            _port,
                            _scheme);
   
   /* Login if we are using authentication */
    if ( _user != null ) {
      
      wilting.login(_user,
                    _password);
    }
   
     void localCompleter () {
       
       JsonObject res = wilting.completionResponse;
       completer.complete(res);
       
     }
     /* Prepare the documents */
     List documentList = new List<String>();
     docList.forEach((key, document) {
       
       String docString = WiltUserUtils.addDocumentId(document.payload,
                                                               key);
       if ( document.rev != null ) {
       
         JsonObject temp = new JsonObject.fromJsonString(docString);
         docString = WiltUserUtils.addDocumentRev(temp, document.rev);
       }
       
       documentList.add(docString);
       
     });
     
     String docs = WiltUserUtils.createBulkInsertString(documentList);
        
     /* Do the bulk create*/
     wilting.resultCompletion = localCompleter;
     wilting.db = _dbName;
     wilting.bulkString(docs);
     
     return completer.future;
    
  }
  
  /**
   * Update the revision of any attachments for a document
   * if the document is updated from Couch
   */
  void updateAttachmentRevisions(String id,
                                 String revision) {
    
    
    lawndart.all().listen((Map document) {
      
      String key = document['key'];
        List keyList = key.split('-');
        if ( (keyList.length == 3) &&
            (keyList[2] == ATTACHMENTMARKER) ) {
          
          if ( id == keyList[0]) {
            
            JsonObject attachment = new JsonObject.fromMap(document);
            updateLocalStorageObject(id,
                                     attachment,
                                     revision,
                                     UPDATED);
            
          }
          
        }
       
    });
    
  }
  
  /**
   * Synchronise local storage with CouchDb
   */
  void sync() {
       
    /*
     * Pending deletes first
     */
    pendingDeletes.forEach((String key, JsonObject document) {
      
      /**
       * If there is no revision the document hasn't been updated 
       * from Couch, we have to ignore this here.
       */
      String revision = document.rev;
      if ( revision != null ) {
       
         /* Check for an attachment */
         List keyList = key.split('-');
         if ( (keyList.length == 3) &&
              (keyList[2] == _SporranDatabase.ATTACHMENTMARKER) ) {
         
          deleteAttachment(keyList[0],
                           keyList[1],
                           revision);
          /* Just in case */
          lawndart.removeByKey(key);
         
        } else {
         
          delete(key,
                 revision);
         
        }
     }
       
   });
    
   pendingDeletes.clear(); 
     
   Map documentsToUpdate  = new Map<String, JsonObject>();
   Map attachmentsToUpdate = new Map<String, JsonObject>();
   
   /**
    * Get a list of non updated documents and attachments from Lawndart and the hot cache
    */
   lawndart.all().listen((Map document) {
     
       String key = document['key'];
       if ( document['status'] == NOT_UPDATED ) {
         
         JsonObject update = new JsonObject.fromMap(document);
         /* If an attachment just stack it */
         List keyList = key.split('-');
         if ( (keyList.length == 3) &&
             (keyList[2] == ATTACHMENTMARKER) ) {
           
           attachmentsToUpdate[key] = update;
           
         } else {
           
          documentsToUpdate[key] = update;
          
         }
         
       }
       
     
   }, onDone:() {
     
     /*
      * Loop around the hot cache, everything in here is not updated yet
      */
     _hotCache.forEach((String key, JsonObject document) {
       
       JsonObject update = new JsonObject.fromMap(document);
       /* If an attachment just stack it */
       List keyList = key.split('-');
       if ( (keyList.length == 3) &&
           (keyList[2] == ATTACHMENTMARKER) ) {
         
          attachmentsToUpdate[key] = update;
         
       } else {
         
          documentsToUpdate[key] = update;
       
       }
       
     });
     
     manualBulkInsert(documentsToUpdate)..
     then((revisions) {
      
      /* Finally do the attachments */
      attachmentsToUpdate.forEach((String key, JsonObject attachment) {
        
        List keyList = key.split('-');
        if ( attachment.rev == null ) attachment.rev = revisions[keyList[0]];
        updateAttachment(keyList[0],
                         attachment.payload.attachmentName,
                         attachment.rev,
                         attachment.payload.contentType,
                         attachment.payload.payload); 
        
      });
           
    });
   
   });
  
  }  
  
}