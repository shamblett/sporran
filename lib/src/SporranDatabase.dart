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
  
  static final NOT_UPDATED = "not_updated";
  static final UPDATED = "updated";
  
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
                  String hostName,
                  [String port = "5984",
                   String scheme = "http://",
                   String userName = null,
                   String password = null]) {
    
    
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
    _wilt = new Wilt(hostName,
                     port,
                     scheme);
    
    if ( userName != null ) {
      
      _wilt.login(userName,
                  password);
    }
    
    /**
     * Connect to CouchDb
     */
    _connectToCouch();
   
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
      
      
      
    } else {
      
      
      
      
    }
    
    
  }
  
  /**
   * Create and/or connect to CouchDb
   */
  _connectToCouch() {
    
    
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
  
}