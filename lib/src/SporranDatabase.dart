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
  /// Constants
  static final String notUpdatedc = "not_updated";
  static final String updatedc = "updated";
  static final String attachmentMarkerc = "sporranAttachment";

  /// Construction, for Wilt we need URL and authentication parameters.
  /// For LawnDart only the database name, the store name is fixed by Sporran
  _SporranDatabase(this._dbName, this._host,
      [this._manualNotificationControl = false,
      this._port = "5984",
      this._scheme = "http://",
      this._user = null,
      this._password = null,
      this._preserveLocalDatabase = false]) {
    _initialise();
  }

  Future _initialise() async {
    _lawndart = await IndexedDbStore.open(this._dbName, "Sporran");
    _lawnIsOpen = true;
    // Delete the local database unless told to preserve it.
    if (!_preserveLocalDatabase) _lawndart.nuke();
    // Instantiate a Wilt object
    _wilt = new WiltBrowserClient(_host, _port, _scheme);
    // Login
    if (_user != null) {
      _wilt.login(_user, _password);
    }
    // Open CouchDb
    connectToCouch();
  }

  /// Host name
  String _host = null;
  String get host => _host;

  /// Port number
  String _port = null;
  String get port => _port;

  /// HTTP scheme
  String _scheme = null;
  String get scheme => _scheme;

  /// Authentication, user name
  String _user = null;

  /// Authentication, user password
  String _password = null;

  /// Manual notification control
  bool _manualNotificationControl = false;
  bool get manualNotificationControl => _manualNotificationControl;

  /// Local database preservation
  bool _preserveLocalDatabase = false;

  /// The Wilt database
  WiltBrowserClient _wilt;
  WiltBrowserClient get wilt => _wilt;

  /// The Lawndart database
  Store _lawndart;
  Store get lawndart => _lawndart;

  /// Lawn is open indicator
  bool _lawnIsOpen = false;

  bool get lawnIsOpen => _lawnIsOpen;

  /// Database name
  String _dbName;
  String get dbName => _dbName;

  /// CouchDb database is intact
  bool _noCouchDb = true;
  bool get noCouchDb => _noCouchDb;

  /// Pending delete queue
  Map _pendingDeletes = new Map<String, JsonObjectLite>();
  Map get pendingDeletes => _pendingDeletes;

  /// Event stream for Ready events
  final _onReady = new StreamController<Event>.broadcast();
  Stream get onReady => _onReady.stream;

  /// Start change notifications
  void startChangeNotifications() {
    final WiltChangeNotificationParameters parameters =
        new WiltChangeNotificationParameters();
    parameters.includeDocs = true;
    _wilt.startChangeNotification(parameters);

    /* Listen for and process changes */
    _wilt.changeNotification.listen((e) {
      _processChange(e);
    });
  }

  /// Change notification processor
  void _processChange(WiltChangeNotificationEvent e) {
    /* Ignore error events */
    if (!(e.type == WiltChangeNotificationEvent.updatee ||
        e.type == WiltChangeNotificationEvent.deletee)) return;

    /* Process the update or delete event */
    if (e.type == WiltChangeNotificationEvent.updatee) {
      updateLocalStorageObject(e.docId, e.document, e.docRevision, updatedc);

      /* Now update the attachments */

      /* Get a list of attachments from the document */
      final List attachments = WiltUserUtils.getAttachments(e.document);
      final List attachmentsToDelete = new List<String>();

      /* For all the keys... */
      _lawndart.keys().listen((String key) {
        /* If an attachment... */
        final List keyList = key.split('-');
        if ((keyList.length == 3) && (keyList[2] == attachmentMarkerc)) {
          /* ...for this document... */
          if (e.docId == keyList[0]) {
            /* ..potentially now deleted... */
            attachmentsToDelete.add(key);

            /* ...check against all the documents current attachments */
            attachments.forEach((attachment) {
              if ((keyList[1] == attachment.name) &&
                  (keyList[0] == e.docId) &&
                  (keyList[2] == attachmentMarkerc)) {
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
      _lawndart.removeByKey(e.docId)
        ..then((_) {
          /* Remove all document attachments */
          _lawndart.keys().listen((String key) {
            final List keyList = key.split('-');
            if ((keyList.length == 3) && (keyList[2] == attachmentMarkerc)) {
              _lawndart.removeByKey(key);
            }
          });
        });
    }
  }

  /// Signal we are ready
  void _signalReady() {
    final Event e = new Event.eventType('Event', 'SporranReady');
    _onReady.add(e);
  }

  /// Create and/or connect to CouchDb
  void connectToCouch([bool transitionToOnline = false]) {
    /// If the CouchDb database does not exist create it.
    void createCompleter(dynamic res) {
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

    void allCompleter(dynamic res) {
      if (!res.error) {
        final JsonObjectLite successResponse = res.jsonCouchResponse;
        final bool created = successResponse.contains(_dbName);
        if (created == false) {
          _wilt.createDatabase(_dbName)
            ..then((res) {
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

    _wilt.getAllDbs()
      ..then((res) {
        allCompleter(res);
      })
      ..catchError((error) {
        _noCouchDb = true;
        _signalReady();
      });
  }

  /// Add a key to the pending delete queue
  void addPendingDelete(String key, String document) {
    final JsonObjectLite deletedDocument =
    new JsonObjectLite.fromJsonString(document);
    _pendingDeletes[key] = deletedDocument;
  }

  /// Remove a key from the pending delete queue
  void removePendingDelete(String key) {
    if (_pendingDeletes.containsKey(key)) _pendingDeletes.remove(key);
  }

  /*
   * Length of the pending delete queue
   */
  int pendingLength() {
    return _pendingDeletes.length;
  }

  /// Update document attachments
  void updateDocumentAttachments(String id, JsonObjectLite document) {
    /* Get a list of attachments from the document */
    final List attachments = WiltUserUtils.getAttachments(document);

    /* Exit if none */
    if (attachments.length == 0) return;

    /* Create our own Wilt instance */
    final Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {
      wilting.login(_user, _password);
    }

    /* Get and update all the attachments */
    attachments.forEach((attachment) {
      void completer(dynamic res) {
        if (!res.error) {
          final dynamic successResponse = res.jsonCouchResponse;
          final dynamic newAttachment = new JsonObjectLite();
          newAttachment.attachmentName = attachment.name;
          newAttachment.rev = WiltUserUtils.getDocumentRev(document);
          newAttachment.contentType = successResponse.contentType;
          newAttachment.payload = res.responseText;
          final String key =
              "$id-${attachment.name}-${_SporranDatabase.attachmentMarkerc}";
          updateLocalStorageObject(
              key, newAttachment, newAttachment.rev, _SporranDatabase.updatedc);
        }
      }

      /* Get the attachment */
      wilting.db = _dbName;
      wilting.getAttachment(id, attachment.name)
        ..then((res) {
          completer(res);
        });
    });
  }

  /// Create local storage updated entry
  JsonObjectLite _createUpdated(String key, String revision,
      JsonObjectLite payload) {
    /* Add our type marker and set to 'not updated' */
    final dynamic update = new JsonObjectLite();
    update.status = updatedc;
    update.key = key;
    update.payload = payload;
    update.rev = revision;
    return update;
  }

  /// Create local storage not updated entry
  JsonObjectLite _createNotUpdated(String key, String revision,
      JsonObjectLite payload) {
    /* Add our type marker and set to 'not updated' */
    final dynamic update = new JsonObjectLite();
    update.status = notUpdatedc;
    update.key = key;
    update.payload = payload;
    update.rev = revision;
    return update;
  }

  /// Update local storage.
  ///
  Future updateLocalStorageObject(String key, JsonObjectLite update,
      String revision, String updateStatus) {
    final completer = new Completer();

    /* Check for not initialized */
    if ((lawndart == null) || (!_lawnIsOpen)) {
      return new Future.error(
          new SporranException(SporranException.lawnNotInitEx));
    }

    /* Do the update */
    JsonObjectLite localUpdate = new JsonObjectLite();
    if (updateStatus == notUpdatedc) {
      localUpdate = _createNotUpdated(key, revision, update);
    } else {
      localUpdate = _createUpdated(key, revision, update);
    }

    /**
     * Update LawnDart
     */
    _lawndart.save(localUpdate.toString(), key)
      ..then((String key) {
        completer.complete();
      });

    return completer.future;
  }

  /// Get an object from local storage
  Future<JsonObjectLite> getLocalStorageObject(String key) {
    final dynamic localObject = new JsonObjectLite();
    final Completer<JsonObjectLite> completer = new Completer<JsonObjectLite>();

    lawndart.getByKey(key).then((String document) {
      if (document != null) {
        localObject.payload = document;
      }

      completer.complete(localObject);
    });

    return completer.future;
  }

  /// Get multiple objects from local storage
  Future<Map> getLocalStorageObjects(
      List<String> keys) {
    final Completer<Map> completer =
    new Completer<Map>();
    final Map results = new Map<String, JsonObjectLite>();
    int keyPos = 0;

    lawndart.getByKeys(keys).listen((String value) {
      final JsonObjectLite document = new JsonObjectLite.fromJsonString(value);
      results[keys[keyPos]] = document;
      keyPos++;
    }, onDone: () {
      completer.complete(results);
    });

    return completer.future;
  }

  /// Delete a CouchDb document.
  ///
  /// If this fails we probably have a conflict in which case
  /// Couch wins.
  void delete(String key, String revision) {
    /* Create our own Wilt instance */
    final Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {
      wilting.login(_user, _password);
    }

    wilting.db = _dbName;
    wilting.deleteDocument(key, revision);
  }

  /// Delete a CouchDb attachment.
  ///
  /// If this fails we probably have a conflict in which case
  /// Couch wins.
  void deleteAttachment(String key, String name, String revision) {
    /* Create our own Wilt instance */
    final Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {
      wilting.login(_user, _password);
    }

    wilting.db = _dbName;
    wilting.deleteAttachment(key, name, revision);
  }

  /// Update/create a CouchDb attachment
  void updateAttachment(String key, String name, String revision,
      String contentType, String payload) {
    /* Create our own Wilt instance */
    final Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {
      wilting.login(_user, _password);
    }

    void getCompleter(dynamic res) {
      /**
       * If the document doesn't already have an attachment
       * with this name get the revision and add this one.
       * We don't care about the outcome, if it errors there's
       * nothing we can do.
       */
      if (!res.error) {
        final JsonObjectLite successResponse = res.jsonCouchResponse;
        final List attachments = WiltUserUtils.getAttachments(successResponse);
        bool found = false;
        attachments.forEach((dynamic attachment) {
          if (attachment.name == name) found = true;
        });

        if (!found) {
          final String newRevision =
              WiltUserUtils.getDocumentRev(successResponse);
          wilting.updateAttachment(
              key, name, newRevision, contentType, payload);
        }
      }
    }

    void putCompleter(dynamic res) {
      /**
       * If we have a conflict, get the document to get its
       * latest revision
       */
      if (res.error) {
        if (res.errorCode == 409) {
          wilting.getDocument(key)
            ..then((res) {
              getCompleter(res);
            });
        }
      }
    }

    wilting.db = _dbName;
    wilting.updateAttachment(key, name, revision, contentType, payload)
      ..then((res) {
        putCompleter(res);
      });
  }

  /// Update/create a CouchDb document
  Future<String> update(String key, JsonObjectLite document, String revision) {
    final Completer<String> completer = new Completer<String>();

    /* Create our own Wilt instance */
    final Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {
      wilting.login(_user, _password);
    }

    void localCompleter(dynamic res) {
      if (!res.error) {
        completer.complete(res.jsonCouchResponse.rev);
      }
    }

    wilting.db = _dbName;
    wilting.putDocument(key, document, revision)
      ..then((res) {
        localCompleter(res);
      });

    return completer.future;
  }

  /// Manual bulk insert uses update
  Future<Map<String, String>> _manualBulkInsert(
      Map<String, JsonObjectLite> documentsToUpdate) {
    final Completer<Map> completer = new Completer<Map>();
    final Map revisions = new Map<String, String>();

    final int length = documentsToUpdate.length;
    int count = 0;
    documentsToUpdate.forEach((String key, dynamic document) {
      update(key, document.payload, document.rev)
        ..then((String rev) {
          revisions[document.key] = rev;
          count++;
          if (count == length) completer.complete(revisions);
        });
    });

    return completer.future;
  }

  /// Bulk insert documents using bulk insert
  Future<JsonObjectLite> bulkInsert(Map<String, dynamic> docList) {
    final Completer<JsonObjectLite> completer = new Completer<JsonObjectLite>();

    /* Create our own Wilt instance */
    final Wilt wilting = new WiltBrowserClient(_host, _port, _scheme);

    /* Login if we are using authentication */
    if (_user != null) {
      wilting.login(_user, _password);
    }

    /* Prepare the documents */
    final List documentList = new List<String>();
    docList.forEach((key, document) {
      String docString = WiltUserUtils.addDocumentId(document.payload, key);
      if (document.rev != null) {
        final JsonObjectLite temp =
        new JsonObjectLite.fromJsonString(docString);
        docString = WiltUserUtils.addDocumentRev(temp, document.rev);
      }

      documentList.add(docString);
    });

    final String docs = WiltUserUtils.createBulkInsertString(documentList);

    /* Do the bulk create*/
    wilting.db = _dbName;
    wilting.bulkString(docs)
      ..then((res) {
        completer.complete(res);
      });

    return completer.future;
  }

  /// Update the revision of any attachments for a document
  /// if the document is updated from Couch
  void updateAttachmentRevisions(String id, String revision) {
    lawndart.all().listen((String document) {
      final String key = document;
      final List keyList = key.split('-');
      if ((keyList.length == 3) && (keyList[2] == attachmentMarkerc)) {
        if (id == keyList[0]) {
          final JsonObjectLite attachment =
          new JsonObjectLite.fromJsonString(document);
          updateLocalStorageObject(id, attachment, revision, updatedc);
        }
      }
    });
  }

  /// Synchronise local storage with CouchDb
  void sync() {
    /*
     * Pending deletes first
     */
    pendingDeletes.forEach((key, dynamic document) {
      /**
       * If there is no revision the document hasn't been updated
       * from Couch, we have to ignore this here.
       */
      final String revision = document.rev;
      if (revision != null) {
        /* Check for an attachment */
        final List keyList = key.split('-');
        if ((keyList.length == 3) &&
            (keyList[2] == _SporranDatabase.attachmentMarkerc)) {
          deleteAttachment(keyList[0], keyList[1], revision);
          /* Just in case */
          lawndart.removeByKey(key);
        } else {
          delete(key, revision);
        }
      }
    });

    pendingDeletes.clear();

    final Map documentsToUpdate = new Map<String, JsonObjectLite>();
    final Map attachmentsToUpdate = new Map<String, JsonObjectLite>();

    /**
    * Get a list of non updated documents and attachments from Lawndart
    */
    lawndart.all().listen((String document) {
      final JsonObjectLite doc = new JsonObjectLite.fromJsonString(document);
      final String key = doc['key'];
      if (doc['status'] == notUpdatedc) {
        final JsonObjectLite update = doc;
        /* If an attachment just stack it */
        final List keyList = key.split('-');
        if ((keyList.length == 3) && (keyList[2] == attachmentMarkerc)) {
          attachmentsToUpdate[key] = update;
        } else {
          documentsToUpdate[key] = update;
        }
      }
    }, onDone: () {
      _manualBulkInsert(documentsToUpdate)
        ..then((revisions) {
          /* Finally do the attachments */
          attachmentsToUpdate.forEach((key, dynamic attachment) {
            final List keyList = key.split('-');
            if (attachment.rev == null) attachment.rev = revisions[keyList[0]];
            updateAttachment(
                keyList[0],
                attachment.payload.attachmentName,
                attachment.rev,
                attachment.payload.contentType,
                attachment.payload.payload);
          });
        });
    });
  }

  /// Create document attachments
  void createDocumentAttachments(String key, JsonObjectLite document) {
    /* Get the attachments and create them locally */
    final List attachments = WiltUserUtils.getAttachments(document);

    attachments.forEach((dynamic attachment) {
      final dynamic attachmentToCreate = new JsonObjectLite();
      attachmentToCreate.attachmentName = attachment.name;
      final String attachmentKey =
          "$key-${attachment.name}-${attachmentMarkerc}";
      attachmentToCreate.rev = WiltUserUtils.getDocumentRev(document);
      attachmentToCreate.contentType = attachment.data.content_type;
      attachmentToCreate.payload = window.btoa(attachment.data.data);

      updateLocalStorageObject(
          attachmentKey, attachmentToCreate, attachmentToCreate.rev, updatedc);
    });
  }

  /// Login
  void login(String user, String password) {
    this._user = user;
    this._password = password;

    _wilt.login(_user, _password);
  }
}
