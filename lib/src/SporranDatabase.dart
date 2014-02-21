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
  Queue _pendingDeletes = new Queue<String>();
  
  bool _lawnIsOpen = false;
  bool get lawnIsOpen => _lawnIsOpen;
  
  /**
   * Event stream for Ready events
   */
  final _onReady = new StreamController.broadcast();
  Stream get onReady => _onReady.stream;
  
  
  /**
   * Create local storage updated entry 
   */
  JsonObject _createUpdated(String key,
                           JsonObject payload) {
    
    /* Add our type marker and set to 'not updated' */
    JsonObject update = new JsonObject();
    update.status = UPDATED;
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
    update.status = NOT_UPDATED;
    update.payload = payload;
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
                                String updateStatus) {
    
    /* Check for not initialized */
    if ( (lawndart == null) || 
         (!lawndart.isOpen ) )
      throw new SporranException("Initialisation Failure, Lawndart is not initialized");
    
    
    /* Do the update */
    JsonObject localUpdate = new JsonObject();
    if ( updateStatus == NOT_UPDATED) {
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
    put(key, localUpdate);
    _lawndart.save(localUpdate, key)
    ..then((String key) {
      
      remove(key);
      
    });
  
    
  }
  
  /**
   * Construction, for Wilt we need URL and authentication parameters.
   * For LawnDart only the database name, the store name is fixed by Sporran
   */
  _SporranDatabase(this._dbName,
                   this._host,
                  [this._port = "5984",
                   this._scheme = "http://",
                   this._user = null,
                   this._password = null]) {
    
    
    /**
     * Instantiate a Store object
     */
    _lawndart = new Store(this._dbName,
                          "Sporran");
    
    /**
     * Open it, note the when ready event is raised
     * from the CouchDb open processing, not here, this will
     * always have completed before CouchDb does.
     */
    _lawndart.open()
      ..then((_) => _lawndart.nuke())
      ..then((_) => _lawnIsOpen = true);
      
    /**
     * Instantiate a Wilt object
     */
    _wilt = new Wilt(_host,
                     _port,
                     _scheme);
    
    if ( _user != null ) {
      
      _wilt.login(_user,
                  _password);
    }
    
    /**
     * Connect to CouchDb
     */
    connectToCouch();
   
  }
  
  /**
   * Start change notifications
   */
  _startChangeNotifications() {
    
    WiltChangeNotificationParameters parameters = new WiltChangeNotificationParameters();
    parameters.includeDocs = true;
   _wilt.startChangeNotification(parameters);
   
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
      
      
      updateLocalStorageObject(e.docId,
                               e.document,
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
   * Create and/or connect to CouchDb
   */
 void connectToCouch() {
    
    
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
      _startChangeNotifications();
      
      /**
       * Signal we are ready
       */
      Event e = new Event.eventType('Event', 'ready');
      _onReady.add(e);
      
      
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
          _startChangeNotifications();
          
         /**
          * Signal we are ready
          */
          Event e = new Event.eventType('Event', 'ready');
          _onReady.add(e);
          
        }
        
      } else {
        
        _noCouchDb = true;
        Event e = new Event.eventType('Event', 'ready');
        _onReady.add(e);
        
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
  void addPendingDelete(String key) {
    
    
    _pendingDeletes.add(key);
    
  }
  
  /**
   * Remove a key from the pending delete queue
   */
  void removePendingDelete(String key) {
    
    
    if ( _pendingDeletes.contains(key) ) _pendingDeletes.remove(key);
    
    
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
}