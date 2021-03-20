/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 * 
 * Sporran is a pouchdb alike for Dart.
 * 
 */

part of sporran;

/// The main Sporran Database class.
///
/// A Sporran database comprises of a WiltBrowserClient object, and a
/// Lawndart object and in tandem, sharing the same database name.
///
/// Please read the usage and interface documentation supplied for
/// further details.
class _SporranDatabase {
  /// Construction, for Wilt we need URL and authentication parameters.
  /// For LawnDart only the database name, the store name is fixed by Sporran
  _SporranDatabase(this._dbName, this._host,
      [this._manualNotificationControl = false,
      this._port = 5984,
      this._scheme = 'http://',
      this._user = '',
      this._password = '',
      this._preserveLocalDatabase = false]) {
    _initialise();
  }

  /// Constants
  static const String notUpdatedc = 'not_updated';
  static const String updatedc = 'updated';
  static const String attachmentMarkerc = 'sporranAttachment';

  Future<dynamic> _initialise() async {
    _lawndart = await IndexedDbStore.open(_dbName, 'Sporran');
    _lawnIsOpen = true;
    // Delete the local database unless told to preserve it.
    if (_preserveLocalDatabase) {
      await _lawndart.nuke();
    }
    // Instantiate a Wilt object
    _wilt = Wilt(_host, port: _port);
    // Login
    if (_user.isNotEmpty) {
      _wilt.login(_user, _password);
    }
    // Open CouchDb
    connectToCouch();
  }

  /// Host name
  final _host;
  String get host => _host;

  /// Port number
  final int _port;
  int get port => _port;

  /// HTTP scheme
  final String _scheme;
  String get scheme => _scheme;

  /// Authentication, user name
  String _user;

  /// Authentication, user password
  String _password;

  /// Manual notification control
  final bool _manualNotificationControl;
  bool get manualNotificationControl => _manualNotificationControl;

  /// Local database preservation
  final bool _preserveLocalDatabase;

  /// The Wilt database
  late Wilt _wilt;
  Wilt get wilt => _wilt;

  /// The Lawndart database
  late Store _lawndart;
  Store get lawndart => _lawndart;

  /// Lawn is open indicator
  bool _lawnIsOpen = false;

  bool get lawnIsOpen => _lawnIsOpen;

  /// Database name
  final _dbName;
  String get dbName => _dbName;

  /// CouchDb database is intact
  bool _noCouchDb = true;
  bool get noCouchDb => _noCouchDb;

  /// Pending delete queue
  final Map<String, JsonObjectLite<dynamic>> _pendingDeletes =
      <String, JsonObjectLite<dynamic>>{};

  Map<String, JsonObjectLite<dynamic>> get pendingDeletes => _pendingDeletes;

  /// Event stream for Ready events
  final dynamic _onReady = StreamController<Event>.broadcast();

  Stream<dynamic>? get onReady => _onReady.stream;

  /// Start change notifications
  void startChangeNotifications() {
    final parameters = WiltChangeNotificationParameters();
    parameters.includeDocs = true;
    _wilt.startChangeNotification(parameters);

    /* Listen for and process changes */
    _wilt.changeNotification.listen(_processChange);
  }

  /// Change notification processor
  Future<void> _processChange(WiltChangeNotificationEvent e) async {
    /* Ignore error events */
    if (!(e.type == WiltChangeNotificationEvent.updatee ||
        e.type == WiltChangeNotificationEvent.deletee)) {
      return;
    }

    /* Process the update or delete event */
    if (e.type == WiltChangeNotificationEvent.updatee) {
      await updateLocalStorageObject(
          e.docId!, e.document!, e.docRevision!, updatedc);

      /* Now update the attachments */

      /* Get a list of attachments from the document */
      final attachments = WiltUserUtils.getAttachments(e.document);
      final attachmentsToDelete = <String>[];

      /* For all the keys... */
      _lawndart.keys().listen((String key) {
        /* If an attachment... */
        final keyList = key.split('-');
        if ((keyList.length == 3) && (keyList[2] == attachmentMarkerc)) {
          /* ...for this document... */
          if (e.docId == keyList[0]) {
            /* ..potentially now deleted... */
            attachmentsToDelete.add(key);

            /* ...check against all the documents current attachments */
            for (final dynamic attachment in attachments) {
              if ((keyList[1] == attachment.name) &&
                  (keyList[0] == e.docId) &&
                  (keyList[2] == attachmentMarkerc)) {
                /* If still valid remove it from the delete list */
                attachmentsToDelete.remove(key);
              }
            }
          }
        }
      }, onDone: () async {
        /* We now have a list of attachments for this document that
          * are not present in the document itself so remove them.
          */
        for (final dynamic key in attachmentsToDelete) {
          await _lawndart.removeByKey(key);
          removePendingDelete(key);
        }
      });

      /* Now update already existing ones and add any ones */
      updateDocumentAttachments(e.docId!, e.document!);
    } else {
      /* Tidy up any pending deletes */
      removePendingDelete(e.docId!);

      /* Do the delete */
      await _lawndart.removeByKey(e.docId!).then((_) {
        /* Remove all document attachments */
        _lawndart.keys().listen((String key) {
          final keyList = key.split('-');
          if ((keyList.length == 3) && (keyList[2] == attachmentMarkerc)) {
            _lawndart.removeByKey(key);
          }
        });
      });
    }
  }

  /// Signal we are ready
  void _signalReady() {
    final e = Event.eventType('Event', 'SporranReady');
    _onReady.add(e);
  }

  /// Create and/or connect to CouchDb
  void connectToCouch([bool transitionToOnline = false]) {
    /// If the CouchDb database does not exist create it.
    void createCompleter(dynamic res) {
      if (!res.error) {
        _wilt.db = _dbName!;
        _noCouchDb = false;
      } else {
        _noCouchDb = true;
      }

      /**
       * Start change notifications
       */
      if (!manualNotificationControl) {
        startChangeNotifications();
      }

      /**
       * If this is a transition to online start syncing
       */
      if (transitionToOnline) {
        sync();
      }

      /**
       * Signal we are ready
       */
      _signalReady();
    }

    void allCompleter(dynamic res) {
      if (!res.error) {
        final JsonObjectLite<dynamic> successResponse = res.jsonCouchResponse;
        final created = successResponse.contains(_dbName);
        if (created == false) {
          _wilt.createDatabase(_dbName!).then(createCompleter);
        } else {
          _wilt.db = _dbName;
          _noCouchDb = false;

          /**
           * Start change notifications
           */
          if (!manualNotificationControl) {
            startChangeNotifications();
          }

          /**
           * If this is a transition to online start syncing
           */
          if (transitionToOnline) {
            sync();
          }

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
      ..then(allCompleter)
      ..catchError((dynamic error) {
        _noCouchDb = true;
        _signalReady();
      });
  }

  /// Add a key to the pending delete queue
  void addPendingDelete(String key, String document) {
    final deletedDocument = JsonObjectLite<dynamic>.fromJsonString(document);
    _pendingDeletes[key] = deletedDocument;
  }

  /// Remove a key from the pending delete queue
  void removePendingDelete(String key) {
    if (_pendingDeletes.containsKey(key)) {
      _pendingDeletes.remove(key);
    }
  }

  /*
   * Length of the pending delete queue
   */
  int pendingLength() => _pendingDeletes.length;

  /// Update document attachments
  void updateDocumentAttachments(String id, JsonObjectLite<dynamic> document) {
    /* Get a list of attachments from the document */
    final attachments = WiltUserUtils.getAttachments(document);

    /* Exit if none */
    if (attachments.isEmpty) {
      return;
    }

    /* Create our own Wilt instance */
    final wilting = Wilt(_host, port: _port);

    /* Login if we are using authentication */
    if (_user.isNotEmpty) {
      wilting.login(_user, _password);
    }

    /* Get and update all the attachments */
    for (final dynamic attachment in attachments) {
      void completer(dynamic res) {
        if (!res.error) {
          final dynamic successResponse = res.jsonCouchResponse;
          final dynamic newAttachment = JsonObjectLite<dynamic>();
          newAttachment.attachmentName = attachment.name;
          newAttachment.rev = WiltUserUtils.getDocumentRev(document);
          newAttachment.contentType = successResponse.contentType;
          newAttachment.payload = res.responseText;
          final key =
              '$id-${attachment.name}-${_SporranDatabase.attachmentMarkerc}';
          updateLocalStorageObject(
              key, newAttachment, newAttachment.rev, _SporranDatabase.updatedc);
        }
      }

      /* Get the attachment */
      wilting.db = _dbName!;
      wilting.getAttachment(id, attachment.name).then(completer);
    }
  }

  /// Create local storage updated entry
  JsonObjectLite<dynamic> _createUpdated(
      String key, String? revision, JsonObjectLite<dynamic>? payload) {
    /* Add our type marker and set to 'not updated' */
    final dynamic update = JsonObjectLite<dynamic>();
    update.status = updatedc;
    update.key = key;
    update.payload = payload;
    update.rev = revision;
    return update;
  }

  /// Create local storage not updated entry
  JsonObjectLite<dynamic> _createNotUpdated(
      String key, String revision, JsonObjectLite<dynamic> payload) {
    /* Add our type marker and set to 'not updated' */
    final dynamic update = JsonObjectLite<dynamic>();
    update.status = notUpdatedc;
    update.key = key;
    update.payload = payload;
    if (revision.isNotEmpty) {
      update.rev = revision;
    }
    return update;
  }

  /// Update local storage.
  ///
  Future<dynamic> updateLocalStorageObject(String key,
      JsonObjectLite<dynamic> update, String revision, String updateStatus) {
    final completer = Completer<dynamic>();

    /* Check for not initialized */
    if (!_lawnIsOpen) {
      return Future<dynamic>.error(
          SporranException(SporranException.lawnNotInitEx));
    }

    /* Do the update */
    var localUpdate = JsonObjectLite<dynamic>();
    if (updateStatus == notUpdatedc) {
      localUpdate = _createNotUpdated(key, revision, update);
    } else {
      localUpdate = _createUpdated(key, revision, update);
    }

    /**
     * Update LawnDart
     */
    _lawndart.save(localUpdate.toString(), key).then((String key) {
      completer.complete();
    });

    return completer.future;
  }

  /// Get an object from local storage.
  /// Returns null if the object cannot be found.
  Future<dynamic> getLocalStorageObject(String key) {
    final dynamic localObject = JsonObjectLite<dynamic>();
    final completer = Completer<dynamic>();

    lawndart.getByKey(key).then((dynamic document) {
      if (document != null) {
        localObject.payload = document;
        completer.complete(localObject);
      } else {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  /// Get multiple objects from local storage
  Future<Map<String, JsonObjectLite<dynamic>>> getLocalStorageObjects(
      List<String> keys) {
    final completer = Completer<Map<String, JsonObjectLite<dynamic>>>();
    final results = <String, JsonObjectLite<dynamic>>{};
    var keyPos = 0;

    lawndart.getByKeys(keys).listen((String value) {
      final document = JsonObjectLite<dynamic>.fromJsonString(value);
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
    final wilting = Wilt(_host, port: _port);

    /* Login if we are using authentication */
    if (_user.isNotEmpty) {
      wilting.login(_user, _password);
    }

    wilting.db = _dbName!;
    wilting.deleteDocument(key, revision);
  }

  /// Delete a CouchDb attachment.
  ///
  /// If this fails we probably have a conflict in which case
  /// Couch wins.
  void deleteAttachment(String key, String name, String revision) {
    /* Create our own Wilt instance */
    final wilting = Wilt(_host, port: _port);

    /* Login if we are using authentication */
    if (_user.isNotEmpty) {
      wilting.login(_user, _password);
    }

    wilting.db = _dbName!;
    wilting.deleteAttachment(key, name, revision);
  }

  /// Update/create a CouchDb attachment
  FutureOr<void> updateAttachment(String key, String name, String revision,
      String contentType, String payload) async {
    /* Create our own Wilt instance */
    final wilting = Wilt(_host, port: _port);

    /* Login if we are using authentication */
    if (_user.isNotEmpty) {
      wilting.login(_user, _password);
    }

    FutureOr<void> getCompleter(dynamic res) async {
      /**
       * If the document doesn't already have an attachment
       * with this name get the revision and add this one.
       * We don't care about the outcome, if it errors there's
       * nothing we can do.
       */
      if (!res.error) {
        final JsonObjectLite<dynamic> successResponse = res.jsonCouchResponse;
        final attachments = WiltUserUtils.getAttachments(successResponse);
        var found = false;
        for (final dynamic attachment in attachments) {
          if (attachment.name == name) {
            found = true;
          }
        }

        if (!found) {
          final newRevision = WiltUserUtils.getDocumentRev(successResponse);
          await wilting.updateAttachment(
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
          wilting.getDocument(key).then(getCompleter);
        }
      }
    }

    wilting.db = _dbName!;
    await wilting
        .updateAttachment(key, name, revision, contentType, payload)
        .then(putCompleter);
  }

  /// Update/create a CouchDb document
  Future<String> update(
      String key, JsonObjectLite<dynamic> document, String revision) {
    final completer = Completer<String>();

    /* Create our own Wilt instance */
    final wilting = Wilt(_host, port: _port);

    /* Login if we are using authentication */
    if (_user.isNotEmpty) {
      wilting.login(_user, _password);
    }

    void localCompleter(dynamic res) {
      if (!res.error) {
        completer.complete(res.jsonCouchResponse.rev);
      }
    }

    wilting.db = _dbName!;
    wilting.putDocument(key, document, revision).then(localCompleter);

    return completer.future;
  }

  /// Manual bulk insert uses update
  Future<Map<String, String>> _manualBulkInsert(
      Map<String?, JsonObjectLite<dynamic>> documentsToUpdate) {
    final completer = Completer<Map<String, String>>();
    final revisions = <String, String>{};

    final length = documentsToUpdate.length;
    var count = 0;
    documentsToUpdate.forEach((String? key, dynamic document) {
      update(key!, document.payload, document.rev).then((String rev) {
        revisions[document.key] = rev;
        count++;
        if (count == length) {
          completer.complete(revisions);
        }
      });
    });

    return completer.future;
  }

  /// Bulk insert documents using bulk insert
  Future<JsonObjectLite<dynamic>> bulkInsert(Map<String, dynamic> docList) {
    final completer = Completer<JsonObjectLite<dynamic>>();

    /* Create our own Wilt instance */
    final wilting = Wilt(_host, port: _port);

    /* Login if we are using authentication */
    if (_user.isNotEmpty) {
      wilting.login(_user, _password);
    }

    /* Prepare the documents */
    final documentList = <String>[];
    docList.forEach((dynamic key, dynamic document) {
      var docString = WiltUserUtils.addDocumentId(document.payload, key);
      if (document.rev != null) {
        final temp = JsonObjectLite<dynamic>.fromJsonString(docString);
        docString = WiltUserUtils.addDocumentRev(temp, document.rev);
      }

      documentList.add(docString);
    });

    final docs = WiltUserUtils.createBulkInsertString(documentList);

    /* Do the bulk create*/
    wilting.db = _dbName!;
    wilting.bulkString(docs).then((dynamic res) {
      completer.complete(res);
    });

    return completer.future;
  }

  /// Update the revision of any attachments for a document
  /// if the document is updated from Couch
  void updateAttachmentRevisions(String id, String revision) {
    lawndart.all().listen((String document) {
      final key = document;
      final keyList = key.split('-');
      if ((keyList.length == 3) && (keyList[2] == attachmentMarkerc)) {
        if (id == keyList[0]) {
          final attachment = JsonObjectLite<dynamic>.fromJsonString(document);
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
    pendingDeletes.forEach((dynamic key, dynamic document) {
      /**
       * If there is no revision the document hasn't been updated
       * from Couch, we have to ignore this here.
       */
      final String? revision = document.rev;
      if (revision != null) {
        /* Check for an attachment */
        final List<String> keyList = key.split('-');
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

    final documentsToUpdate = <String, JsonObjectLite<dynamic>>{};
    final attachmentsToUpdate = <String, JsonObjectLite<dynamic>>{};

    /**
    * Get a list of non updated documents and attachments from Lawndart
    */
    lawndart.all().listen((String document) {
      final doc = JsonObjectLite<dynamic>.fromJsonString(document);
      final String? key = doc['key'];
      if (doc['status'] == notUpdatedc) {
        final update = doc;
        /* If an attachment just stack it */
        final keyList = key!.split('-');
        if ((keyList.length == 3) && (keyList[2] == attachmentMarkerc)) {
          attachmentsToUpdate[key] = update;
        } else {
          documentsToUpdate[key] = update;
        }
      }
    }, onDone: () {
      _manualBulkInsert(documentsToUpdate).then((dynamic revisions) {
        /* Finally do the attachments */
        attachmentsToUpdate.forEach((dynamic key, dynamic attachment) {
          attachment.isImmutable = false;
          final List<String> keyList = key.split('-');
          attachment.rev = revisions[keyList[0]];
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
  void createDocumentAttachments(String key, JsonObjectLite<dynamic> document) {
    /* Get the attachments and create them locally */
    final attachments = WiltUserUtils.getAttachments(document);

    for (final dynamic attachment in attachments) {
      final dynamic attachmentToCreate = JsonObjectLite<dynamic>();
      attachmentToCreate.attachmentName = attachment.name;
      final attachmentKey = '$key-${attachment.name}-$attachmentMarkerc';
      attachmentToCreate.rev = WiltUserUtils.getDocumentRev(document);
      attachmentToCreate.contentType = attachment.data.content_type;
      attachmentToCreate.payload = window.btoa(attachment.data.data);

      updateLocalStorageObject(
          attachmentKey, attachmentToCreate, attachmentToCreate.rev, updatedc);
    }
  }

  /// Login
  void login(String user, String password) {
    _user = user;
    _password = password;

    _wilt.login(_user, _password);
  }
}
