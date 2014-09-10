/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 * 
 * Sporran is a pouchdb alike for Dart.
 * 
 * This is the main Sporran Database class.
 * 
 * A Sporran database comprises of a WiltBrowserClient object, and a a Lawndart 
 * object and in tandem, sharing the same database name.
 * 
 * Please read the usage and interface documentation supplied for
 * further details.
 * 
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
   * Local database preservation 
   */
  bool _preserveLocalDatabase = false;

  /**
   * The Wilt database
   */
  WiltBrowserClient _wilt;
  WiltBrowserClient get wilt => _wilt;

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
  _SporranDatabase(this._dbName, this._host, [this._manualNotificationControl = false, this._port = "5984", this._scheme = "http://", this._user = null, this._password = null, this._preserveLocalDatabase = false]) {


    /**
     * Instantiate a Store object
     */
    _lawndart = new Store(this._dbName, "Sporran");

    /**
     * Open it, don't worry about waiting
     */

    _lawndart.open()..then((_) {

      /**
       * Delete the local database unless told to preserve it.
       */
          if (!_preserveLocalDatabase) _lawndart.nuke();

     /**
      * Instantiate a Wilt object
      */
          _wilt = new WiltBrowserClient(_host, _port, _scheme);

     /**
      * Login
      */
          if (_user != null) {

            _wilt.login(_user, _password);

          }

     /*
      * Open CouchDb
      */
          connectToCouch();

        });

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
    if (!(e.type == WiltChangeNotificationEvent.UPDATE || e.type == WiltChangeNotificationEvent.DELETE)) return;

    /* Process the update or delete event */
    if (e.type == WiltChangeNotificationEvent.UPDATE) {

      updateLocalStorageObject(e.docId, e.document, e.docRevision, UPDATED);

      /* Now update the attachments */

      /* Get a list of attachments from the document */
      List attachments = WiltUserUtils.getAttachments(e.document);
      List attachmentsToDelete = new List<String>();

      /* For all the keys... */
      _lawndart.keys().listen((String key) {

        /* If an attachment... */
        List keyList = key.split('-');
        if ((keyList.length == 3) && (keyList[2] == ATTACHMENTMARKER)) {

          /* ...for this document... */
          if (e.docId == keyList[0]) {

            /* ..potentially now deleted... */
            attachmentsToDelete.add(key);

            /* ...check against all the documents current attachments */
            attachments.forEach((attachment) {

              if ((keyList[1] == attachment.name) && (keyList[0] == e.docId) && (keyList[2] == ATTACHMENTMARKER)) {

                /* If still valid remove it from the delete list */
                attachmentsToDelete.remove(key);

              }

            });

          }

        }

      }, onDone: () {

        /* We now have a list of attachments for this document that 
          * are not present in the document itself so remove them.
          */
        attachmentsToDelete.forEach((key) {

          _lawndart.removeByKey(key)..then((key) => removePendingDelete(key));

        });

      });


      /* Now update already existing ones and add any new ones */
      updateDocumentAttachments(e.docId, e.document);

    } else {

      /* Tidy up any pending deletes */
      removePendingDelete(e.docId);

      /* Do the delete */
      _lawndart.removeByKey(e.docId)..then((_) {

            /* Remove all document attachments */
            _lawndart.keys().listen((String key) {

              List keyList = key.split('-');
              if ((keyList.length == 3) && (keyList[2] == ATTACHMENTMARKER)) {

                _lawndart.removeByKey(key);
              }

            });

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
    void createCompleter(res) {

      if (!res.error) {

        _wilt.db = _dbName;
        _noCouchDb = false;

      } else {

        _noCouchDb = true;

      }

      /**
       * Start change notifications 
       */
      if (!manualNotificationControl) startChangeNotifications();

      /**
       * If this is a transition to online start syncing
       */
      if (transitionToOnline) sync();

      /**
       * Signal we are ready
       */
      _signalReady();


    }
    ;

    void allCompleter(res) {

      if (!res.error) {

        JsonObject successResponse = res.jsonCouchResponse;
        bool created = successResponse.contains(_dbName);
        if (created == false) {

          _wilt.createDatabase(_dbName)..then((res) {
                createCompleter(res);
              });

        } else {

          _wilt.db = _dbName;
          _noCouchDb = false;

          /**
           * Start change notifications 
           */
          if (!manualNotificationControl) startChangeNotifications();

          /**
           * If this is a transition to online start syncing
           */
          if (transitionToOnline) sync();

          /**
          * Signal we are ready
          */
          _signalReady();

        }

      } else {

        _noCouchDb = true;
        _signalReady();

      }

    }
    ;

    _wilt.getAllDbs()..then((res) {
          allCompleter(res);
        });


  }

  /**
   * Add a key to the pending delete queue
   */
  void addPendingDelete(String key, Map document) {

    JsonObject deletedDocument = new JsonObject.fromMap(document);
    _pendingDeletes[key] = deletedDocument;

  }

  /**
   * Remove a key from the pending delete queue
   */
  void removePendingDelete(String key) {


    if (_pendingDeletes.containsKey(key)) _pendingDeletes.remove(key);


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
  void updateDocumentAttachments(String id, JsonObject document) {

    /* Get a list of attachments from the document */
    List attachments = WiltUserUtils.getAttachments(document);

    /* Exit if none */
    if (attachments.length == 0) return;

    /* Create our own Wilt instance */
    Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {

      wilting.login(_user, _password);
    }


    /* Get and update all the attachments */
    attachments.forEach((attachment) {


      void completer(res) {

        if (!res.error) {

          JsonObject successResponse = res.jsonCouchResponse;
          JsonObject newAttachment = new JsonObject();
          newAttachment.attachmentName = attachment.name;
          newAttachment.rev = WiltUserUtils.getDocumentRev(document);
          newAttachment.contentType = successResponse.contentType;
          newAttachment.payload = res.responseText;
          String key = "$id-${attachment.name}-${_SporranDatabase.ATTACHMENTMARKER}";
          updateLocalStorageObject(key, newAttachment, newAttachment.rev, _SporranDatabase.UPDATED);

        }

      }

      /* Get the attachment */
      wilting.db = _dbName;
      wilting.getAttachment(id, attachment.name)..then((res) {
            completer(res);
          });

    });

  }

  /**
   * Create local storage updated entry 
   */
  JsonObject _createUpdated(String key, String revision, JsonObject payload) {

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
  JsonObject _createNotUpdated(String key, String revision, JsonObject payload) {

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
   */
  Future updateLocalStorageObject(String key, JsonObject update, String revision, String updateStatus) {

    var completer = new Completer();

    /* Check for not initialized */
    if ((lawndart == null) || (!lawndart.isOpen)) return new Future.error(new SporranException(SporranException.LAWN_NOT_INIT));


    /* Do the update */
    JsonObject localUpdate = new JsonObject();
    if (updateStatus == NOT_UPDATED) {
      localUpdate = _createNotUpdated(key, revision, update);
    } else {
      localUpdate = _createUpdated(key, revision, update);
    }

    /**
     * Update LawnDart
     */
    _lawndart.save(localUpdate, key)..then((String key) {

          completer.complete();

        });

    return completer.future;

  }


  /**
   * Get an object from local storage
   */
  Future<JsonObject> getLocalStorageObject(String key) {

    JsonObject localObject = new JsonObject();
    var completer = new Completer();

    lawndart.getByKey(key).then((document) {

      JsonObject res = new JsonObject();

      if (document != null) {

        localObject.payload = document['payload'];

      }

      completer.complete(localObject);

    });


    return completer.future;

  }

  /**
   * Get multiple objects from local storage
   */
  Future<Map<String, JsonObject>> getLocalStorageObjects(List<String> keys) {

    var completer = new Completer();
    Map results = new Map<String, JsonObject>();
    int keyPos = 0;

    lawndart.getByKeys(keys).listen((value) {

      JsonObject document = new JsonObject.fromMap(value);
      results[keys[keyPos]] = document;
      keyPos++;

    }, onDone: () {

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
  void delete(String key, String revision) {


    /* Create our own Wilt instance */
    Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {

      wilting.login(_user, _password);
    }

    wilting.db = _dbName;
    wilting.deleteDocument(key, revision);

  }

  /**
   * Delete a CouchDb attachment.
   * 
   * If this fails we probably have a conflict in which case
   * Couch wins.
   */
  void deleteAttachment(String key, String name, String revision) {


    /* Create our own Wilt instance */
    Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {

      wilting.login(_user, _password);
    }

    wilting.db = _dbName;
    wilting.deleteAttachment(key, name, revision);

  }

  /**
   * Update/create a CouchDb attachment
   */
  void updateAttachment(String key, String name, String revision, String contentType, String payload) {


    /* Create our own Wilt instance */
    Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {

      wilting.login(_user, _password);
    }

    void getCompleter(res) {

      /**
       * If the document doesnt already have an attachment 
       * with this name get the revision and add this one.
       * We don't care about the outcome, if it errors there's
       * nothing we can do.
       */
      if (!res.error) {

        JsonObject successResponse = res.jsonCouchResponse;
        List attachments = WiltUserUtils.getAttachments(successResponse);
        bool found = false;
        attachments.forEach((JsonObject attachment) {

          if (attachment.name == name) found = true;

        });

        if (!found) {

          String newRevision = WiltUserUtils.getDocumentRev(successResponse);
          wilting.updateAttachment(key, name, newRevision, contentType, payload);
        }

      }

    }

    void putCompleter(res) {

      /**
       * If we have a conflict, get the document to get its
       * latest revision
       */
      if (res.error) {

        if (res.errorCode == 409) {

          wilting.getDocument(key)..then((res) {
                getCompleter(res);
              });

        }

      }

    }

    wilting.db = _dbName;
    wilting.updateAttachment(key, name, revision, contentType, payload)..then((res) {
          putCompleter(res);
        });


  }

  /**
   * Update/create a CouchDb document
   */
  Future<String> update(String key, JsonObject document, String revision) {


    Completer completer = new Completer();

    /* Create our own Wilt instance */
    Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {

      wilting.login(_user, _password);
    }

    void localCompleter(res) {

      if (!res.error) {

        completer.complete(res.jsonCouchResponse.rev);

      }

    }
    wilting.db = _dbName;
    wilting.putDocument(key, document, revision)..then((res) {
          localCompleter(res);
        });

    return completer.future;

  }

  /**
   * Manual bulk insert uses update
   */
  Future<Map<String, String>> _manualBulkInsert(Map<String, JsonObject> documentsToUpdate) {

    Completer completer = new Completer();
    Map revisions = new Map<String, String>();

    int length = documentsToUpdate.length;
    int count = 0;
    documentsToUpdate.forEach((String key, JsonObject document) {

      update(key, document.payload, document.rev)..then((String rev) {

            revisions[document.key] = rev;
            count++;
            if (count == length) completer.complete(revisions);

          });

    });

    return completer.future;
  }

  /**
   * Bulk insert documents using bulk insert
   */
  Future<JsonObject> bulkInsert(Map<String, JsonObject> docList) {

    var completer = new Completer();

    /* Create our own Wilt instance */
    Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {

      wilting.login(_user, _password);
    }

    /* Prepare the documents */
    List documentList = new List<String>();
    docList.forEach((key, document) {

      String docString = WiltUserUtils.addDocumentId(document.payload, key);
      if (document.rev != null) {

        JsonObject temp = new JsonObject.fromJsonString(docString);
        docString = WiltUserUtils.addDocumentRev(temp, document.rev);
      }

      documentList.add(docString);

    });

    String docs = WiltUserUtils.createBulkInsertString(documentList);

    /* Do the bulk create*/
    wilting.db = _dbName;
    wilting.bulkString(docs)..then((res) {
          completer.complete(res);
        });

    return completer.future;

  }

  /**
   * Update the revision of any attachments for a document
   * if the document is updated from Couch
   */
  void updateAttachmentRevisions(String id, String revision) {


    lawndart.all().listen((Map document) {

      String key = document['key'];
      List keyList = key.split('-');
      if ((keyList.length == 3) && (keyList[2] == ATTACHMENTMARKER)) {

        if (id == keyList[0]) {

          JsonObject attachment = new JsonObject.fromMap(document);
          updateLocalStorageObject(id, attachment, revision, UPDATED);

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
      if (revision != null) {

        /* Check for an attachment */
        List keyList = key.split('-');
        if ((keyList.length == 3) && (keyList[2] == _SporranDatabase.ATTACHMENTMARKER)) {

          deleteAttachment(keyList[0], keyList[1], revision);
          /* Just in case */
          lawndart.removeByKey(key);

        } else {

          delete(key, revision);

        }
      }

    });

    pendingDeletes.clear();

    Map documentsToUpdate = new Map<String, JsonObject>();
    Map attachmentsToUpdate = new Map<String, JsonObject>();

    /**
    * Get a list of non updated documents and attachments from Lawndart
    */
    lawndart.all().listen((Map document) {

      String key = document['key'];
      if (document['status'] == NOT_UPDATED) {

        JsonObject update = new JsonObject.fromMap(document);
        /* If an attachment just stack it */
        List keyList = key.split('-');
        if ((keyList.length == 3) && (keyList[2] == ATTACHMENTMARKER)) {

          attachmentsToUpdate[key] = update;

        } else {

          documentsToUpdate[key] = update;

        }

      }

      _manualBulkInsert(documentsToUpdate)..then((revisions) {

            /* Finally do the attachments */
            attachmentsToUpdate.forEach((String key, JsonObject attachment) {

              List keyList = key.split('-');
              if (attachment.rev == null) attachment.rev = revisions[keyList[0]];
              updateAttachment(keyList[0], attachment.payload.attachmentName, attachment.rev, attachment.payload.contentType, attachment.payload.payload);

            });

          });

    });

  }

  /**
   * Create document attachments
   */
  void createDocumentAttachments(String key, JsonObject document) {


    /* Get the attachments and create them locally */
    List attachments = WiltUserUtils.getAttachments(document);

    attachments.forEach((JsonObject attachment) {

      JsonObject attachmentToCreate = new JsonObject();
      attachmentToCreate.attachmentName = attachment.name;
      String attachmentKey = "$key-${attachment.name}-${ATTACHMENTMARKER}";
      attachmentToCreate.rev = WiltUserUtils.getDocumentRev(document);
      attachmentToCreate.contentType = attachment.data.content_type;
      attachmentToCreate.payload = window.btoa(attachment.data.data);

      updateLocalStorageObject(attachmentKey, attachmentToCreate, attachmentToCreate.rev, UPDATED);


    });


  }

  /**
   * Login 
   */
  void login(String user, String password) {

    this._user = user;
    this._password = password;

    _wilt.login(_user, _password);

  }

}
