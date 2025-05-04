/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 * 
 * Sporran is a pouchdb alike for Dart.
 * 
 */

part of '../sporran.dart';

/// The main Sporran Database class.
///
/// A Sporran database comprises of a WiltBrowserClient object, and a
/// Lawndart object and in tandem, sharing the same database name.
///
/// Please read the usage and interface documentation supplied for
/// further details.
class _SporranDatabase {
  static const dbPort = 5984;
  static const keyListLength = 3;

  /// State constants
  static const String notUpdatedc = 'not_updated';
  static const String updatedc = 'updated';
  static const String attachmentMarkerc = 'sporranAttachment';

  final String _host;

  final int _port;

  final String _scheme;

  // Authentication, user name
  String _user;

  // Authentication, user password
  String _password;

  final bool _manualNotificationControl;

  // Local database preservation
  final bool _preserveLocalDatabase;

  late Wilt _wilt;

  late Store _lawndart;

  bool _lawnIsOpen = false;

  final String _dbName;

  bool _noCouchDb = true;

  final Map<String, JsonObjectLite<dynamic>> _pendingDeletes =
      <String, JsonObjectLite<dynamic>>{};

  final dynamic _onReady = StreamController<Event>.broadcast();

  /// Host name
  String get host => _host;

  /// Port number
  int get port => _port;

  /// HTTP scheme
  String get scheme => _scheme;

  /// Manual notification control
  bool get manualNotificationControl => _manualNotificationControl;

  /// The Wilt database
  Wilt get wilt => _wilt;

  /// The Lawndart database
  Store get lawndart => _lawndart;

  /// Lawn is open indicator
  bool get lawnIsOpen => _lawnIsOpen;

  /// Database name
  String get dbName => _dbName;

  /// CouchDb database is intact
  bool get noCouchDb => _noCouchDb;

  /// Pending delete queue
  Map<String, JsonObjectLite<dynamic>> get pendingDeletes => _pendingDeletes;

  /// Event stream for Ready events
  Stream<dynamic>? get onReady => _onReady.stream;

  /// Construction, for Wilt we need URL and authentication parameters.
  /// For LawnDart only the database name, the store name is fixed by Sporran
  _SporranDatabase(
    this._dbName,
    this._host, [
    this._manualNotificationControl = false,
    this._port = dbPort,
    this._scheme = 'http://',
    this._user = '',
    this._password = '',
    this._preserveLocalDatabase = false,
  ]);

  Future<dynamic> initialise() async {
    _lawndart = await IndexedDbStore.open(_dbName, 'Sporran');
    _lawnIsOpen = true;
    // Delete the local database unless told to preserve it.
    if (!_preserveLocalDatabase) {
      await _lawndart.nuke();
    }
    // Instantiate a Wilt object
    _wilt = Wilt(_host, port: _port);
    // Login
    if (_user.isNotEmpty) {
      _wilt.login(_user, _password);
    }
    // Open CouchDb
    await connectToCouch();
  }

  /// Get the JSON success response from an API operation result.
  JsonObjectLite getJsonResponse(JsonObjectLite result) {
    final JsonObjectLite response = JsonObjectLite();
    JsonObjectLite.toTypedJsonObjectLite(
      (result as dynamic).jsonCouchResponse,
      response,
    );
    return response;
  }

  /// Start change notifications
  void startChangeNotifications() {
    final parameters = WiltChangeNotificationParameters();
    parameters.includeDocs = true;
    _wilt.startChangeNotification(parameters);

    /* Listen for and process changes */
    _wilt.changeNotification.listen(_processChange);
  }

  /// Create and/or connect to CouchDb
  FutureOr<void> connectToCouch([bool transitionToOnline = false]) async {
    final completer = Completer<void>();

    final res = await _wilt.getAllDbs().catchError((dynamic error) {
      _noCouchDb = true;
      _signalReady();
    });

    if (!res.error) {
      final JsonObjectLite<dynamic> successResponse = getJsonResponse(res);
      final created = successResponse.contains(_dbName);
      if (!created) {
        await _wilt.createDatabase(_dbName);
        if (!res.error) {
          _wilt.db = _dbName;
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

    return completer.future;
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
          final dynamic successResponse = getJsonResponse(res);
          final dynamic newAttachment = JsonObjectLite<dynamic>();
          newAttachment.attachmentName = attachment.name;
          newAttachment.rev = WiltUserUtils.getDocumentRev(document);
          newAttachment.contentType = successResponse.contentType;
          newAttachment.payload = res.responseText;
          final key =
              '$id-${attachment.name}-${_SporranDatabase.attachmentMarkerc}';
          updateLocalStorageObject(
            key,
            newAttachment,
            newAttachment.rev,
            _SporranDatabase.updatedc,
          );
        }
      }

      /* Get the attachment */
      wilting.db = _dbName;
      wilting.getAttachment(id, attachment.name).then(completer);
    }
  }

  /// Update local storage.
  ///
  Future<dynamic> updateLocalStorageObject(
    String key,
    JsonObjectLite<dynamic> update,
    String revision,
    String updateStatus,
  ) async {
    final completer = Completer<dynamic>();

    /* Check for not initialized */
    if (!_lawnIsOpen) {
      return Future<dynamic>.error(
        SporranException(SporranException.lawnNotInitEx),
      );
    }

    /* Do the update */
    var localUpdate = JsonObjectLite<dynamic>();
    localUpdate =
        updateStatus == notUpdatedc
            ? _createNotUpdated(key, revision, update)
            : _createUpdated(key, revision, update);

    /**
     * Update LawnDart
     */
    await _lawndart.save(localUpdate.toString(), key);
    completer.complete();
    return completer.future;
  }

  /// Get an object from local storage.
  /// Returns null if the object cannot be found.
  Future<dynamic> getLocalStorageObject(String key) async {
    final dynamic localObject = JsonObjectLite<dynamic>();
    final completer = Completer<dynamic>();

    final document = await lawndart.getByKey(key);
    if (document != null) {
      localObject.payload = document;
      completer.complete(localObject);
    } else {
      completer.complete(null);
    }

    return completer.future;
  }

  /// Get multiple objects from local storage
  Future<Map<String, JsonObjectLite<dynamic>>> getLocalStorageObjects(
    List<String> keys,
  ) {
    final completer = Completer<Map<String, JsonObjectLite<dynamic>>>();
    final results = <String, JsonObjectLite<dynamic>>{};
    var keyPos = 0;

    lawndart
        .getByKeys(keys)
        .listen(
          (String value) {
            final document = JsonObjectLite<dynamic>.fromJsonString(value);
            results[keys[keyPos]] = document;
            keyPos++;
          },
          onDone: () {
            completer.complete(results);
          },
        );

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

    wilting.db = _dbName;
    String docRevision = '';
    if (revision.isNotEmpty) {
      docRevision = revision;
    }
    wilting.deleteDocument(key, docRevision);
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

    wilting.db = _dbName;
    String docRevision = '';
    if (revision.isNotEmpty) {
      docRevision = revision;
    }
    wilting.deleteAttachment(key, name, docRevision);
  }

  /// Update/create a CouchDb attachment
  FutureOr<void> updateAttachment(
    String key,
    String name,
    String revision,
    String contentType,
    String payload,
  ) async {
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
        final JsonObjectLite<dynamic> successResponse = getJsonResponse(res);
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
            key,
            name,
            newRevision,
            contentType,
            payload,
          );
        }
      }
    }

    void putCompleter(dynamic res) {
      /**
       * If we have a conflict, get the document to get its
       * latest revision
       */
      if (res.error) {
        if (res.errorCode == HttpStatus.conflict) {
          wilting.getDocument(key).then(getCompleter);
        }
      }
    }

    wilting.db = _dbName;
    String docRevision = '';
    if (revision.isNotEmpty) {
      docRevision = revision;
    }
    await wilting
        .updateAttachment(key, name, docRevision, contentType, payload)
        .then(putCompleter);
  }

  /// Update/create a CouchDb document
  Future<String> update(
    String key,
    JsonObjectLite<dynamic> document,
    String revision,
  ) async {
    final completer = Completer<String>();

    /* Create our own Wilt instance */
    final wilting = Wilt(_host, port: _port);

    /* Login if we are using authentication */
    if (_user.isNotEmpty) {
      wilting.login(_user, _password);
    }

    void localCompleter(dynamic res) {
      if (!res.error) {
        completer.complete((getJsonResponse(res) as dynamic).rev);
      }
    }

    wilting.db = _dbName;
    String docRevision = '';
    if (revision.isNotEmpty) {
      docRevision = revision;
      await wilting
          .putDocument(key, document, docRevision)
          .then(localCompleter);
    } else {
      await wilting.putDocument(key, document).then(localCompleter);
    }

    return completer.future;
  }

  /// Bulk insert documents using bulk insert
  Future<JsonObjectLite<dynamic>> bulkInsert(
    Map<String, dynamic> docList,
  ) async {
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
    wilting.db = _dbName;
    await wilting.bulkString(docs).then((dynamic res) {
      completer.complete(res);
    });

    return completer.future;
  }

  /// Update the revision of any attachments for a document
  /// if the document is updated from Couch
  void updateAttachmentRevisions(String id, String revision) {
    lawndart.all().listen((String? document) {
      final key = document;
      final keyList = key?.split('-');
      if ((keyList?.length == keyListLength) &&
          (keyList?[2] == attachmentMarkerc)) {
        if (id == keyList?.first) {
          final attachment = JsonObjectLite<dynamic>.fromJsonString(document!);
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
       * from CouchDb.
       */
      String revision = '';
      final jsonDoc = JsonObjectLite();
      JsonObjectLite.toTypedJsonObjectLite(document, jsonDoc);
      if (jsonDoc.containsKey('rev')) {
        revision = document.rev;
      } else {
        return;
      }
      final List<String> keyList = key.split('-');
      if ((keyList.length == keyListLength) &&
          (keyList[2] == _SporranDatabase.attachmentMarkerc)) {
        deleteAttachment(keyList.first, keyList[1], revision);
        /* Just in case */
        lawndart.removeByKey(key);
      }
      // If we have no revision the document is not yet in CouchDb
      // so we can't delete it.
      delete(key, revision);
    });

    pendingDeletes.clear();

    final documentsToUpdate = <String, JsonObjectLite<dynamic>>{};
    final attachmentsToUpdate = <String, JsonObjectLite<dynamic>>{};

    /**
    * Get a list of non updated documents and attachments from Lawndart
    */
    lawndart.all().listen(
      (String? document) {
        final doc = JsonObjectLite<dynamic>.fromJsonString(document!);
        final String? key = doc['key'];
        if (doc['status'] == notUpdatedc) {
          final update = doc;
          /* If an attachment just stack it */
          final keyList = key!.split('-');
          if ((keyList.length == keyListLength) &&
              (keyList[2] == attachmentMarkerc)) {
            attachmentsToUpdate[key] = update;
          } else {
            documentsToUpdate[key] = update;
          }
        }
      },
      onDone: () {
        _manualBulkInsert(documentsToUpdate).then((dynamic revisions) {
          /* Finally do the attachments */
          attachmentsToUpdate.forEach((dynamic key, dynamic attachment) {
            attachment.isImmutable = false;
            final List<String> keyList = key.split('-');
            attachment.rev = revisions[keyList.first];
            if (attachment.rev != null) {
              updateAttachment(
                keyList.first,
                attachment['payload']['attachmentName'],
                attachment['rev'],
                attachment['payload']['contentType'],
                attachment['payload']['payload'],
              );
            }
          });
        });
      },
    );
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
        attachmentKey,
        attachmentToCreate,
        attachmentToCreate.rev,
        updatedc,
      );
    }
  }

  /// Login
  void login(String user, String password) {
    _user = user;
    _password = password;

    _wilt.login(_user, _password);
  }

  // Change notification processor
  Future<void> _processChange(WiltChangeNotificationEvent e) async {
    /* Ignore error events */
    if (!(e.type == WiltChangeNotificationEvent.updatee ||
        e.type == WiltChangeNotificationEvent.deletee)) {
      return;
    }

    /* Process the update or delete event */
    if (e.type == WiltChangeNotificationEvent.updatee) {
      await updateLocalStorageObject(
        e.docId!,
        e.document!,
        e.docRevision!,
        updatedc,
      );

      /* Now update the attachments */

      /* Get a list of attachments from the document */
      final attachments = WiltUserUtils.getAttachments(e.document);
      final attachmentsToDelete = <String>[];

      /* For all the keys... */
      _lawndart.keys().listen(
        (String? key) {
          /* If an attachment... */
          final keyList = key?.split('-');
          if ((keyList?.length == keyListLength) &&
              (keyList?[2] == attachmentMarkerc)) {
            /* ...for this document... */
            if (e.docId == keyList?.first) {
              /* ..potentially now deleted... */
              attachmentsToDelete.add(key!);

              /* ...check against all the documents current attachments */
              for (final dynamic attachment in attachments) {
                if ((keyList?[1] == attachment.name) &&
                    (keyList?.first == e.docId) &&
                    (keyList?[2] == attachmentMarkerc)) {
                  /* If still valid remove it from the delete list */
                  attachmentsToDelete.remove(key);
                }
              }
            }
          }
        },
        onDone: () async {
          /* We now have a list of attachments for this document that
          * are not present in the document itself so remove them.
          */
          for (final dynamic key in attachmentsToDelete) {
            await _lawndart.removeByKey(key);
            removePendingDelete(key);
          }
        },
      );

      /* Now update already existing ones and add any ones */
      updateDocumentAttachments(e.docId!, e.document!);
    } else {
      /* Tidy up any pending deletes */
      removePendingDelete(e.docId!);

      /* Do the delete */
      await _lawndart.removeByKey(e.docId!).then((_) {
        /* Remove all document attachments */
        _lawndart.keys().listen((String? key) async {
          final keyList = key?.split('-');
          if ((keyList?.length == keyListLength) &&
              (keyList?[2] == attachmentMarkerc)) {
            await _lawndart.removeByKey(key!);
          }
        });
      });
    }
  }

  // Signal we are ready
  void _signalReady() {
    final e = Event('SporranReady');
    _onReady.add(e);
  }

  // Create local storage updated entry
  JsonObjectLite<dynamic> _createUpdated(
    String key,
    String? revision,
    JsonObjectLite<dynamic>? payload,
  ) {
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
    String key,
    String revision,
    JsonObjectLite<dynamic> payload,
  ) {
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

  /// Manual bulk insert uses update
  Future<Map<String, String>> _manualBulkInsert(
    Map<String, JsonObjectLite<dynamic>> documentsToUpdate,
  ) async {
    final completer = Completer<Map<String, String>>();
    final revisions = <String, String>{};

    final length = documentsToUpdate.length;
    var count = 0;
    documentsToUpdate.forEach((String key, dynamic document) async {
      final jsonDoc = JsonObjectLite();
      JsonObjectLite.toTypedJsonObjectLite(document, jsonDoc);
      if (!jsonDoc.containsKey('rev')) {
        jsonDoc.isImmutable = false;
        (jsonDoc as dynamic).rev = '';
      }
      await update(
        key,
        (jsonDoc as dynamic).payload,
        (jsonDoc as dynamic).rev,
      ).then((String rev) {
        revisions[document.key] = rev;
        count++;
        if (count == length) {
          completer.complete(revisions);
        }
      });
    });

    return completer.future;
  }
}
