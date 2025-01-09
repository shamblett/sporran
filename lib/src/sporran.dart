//
// Package : Sporran
// Author : S. Hamblett <steve.hamblett@linux.com>
// Date   : 05/02/2014
// Copyright :  S.Hamblett@OSCF
//
// Sporran is a pouchdb alike for Dart.
//
//

part of '../sporran.dart';

///  This is the main Sporran API class.
class Sporran {
  /// Construction.
  Sporran(SporranInitialiser initialiser) {
    _dbName = initialiser.dbName;

    // Construct our database.
    _database = _SporranDatabase(
        _dbName,
        initialiser.hostname,
        initialiser.manualNotificationControl,
        initialiser.port,
        initialiser.scheme,
        initialiser.username,
        initialiser.password,
        initialiser.preserveLocal);
  }

  /// Method constants
  static const String putc = 'put';
  static const String getc = 'get';
  static const String deletec = 'delete';
  static const String putAttachmentc = 'put_attachment';
  static const String getAttachmentc = 'get_attachment';
  static const String deleteAttachmentc = 'delete_attachment';
  static const String bulkCreatec = 'bulk_create';
  static const String getAllDocsc = 'get_all_docs';
  static const String dbInfoc = 'db_info';
  static const String none = 'none';

  /// Database
  late _SporranDatabase _database;

  /// Database name
  String _dbName = '';

  String get dbName => _dbName;

  /// Lawndart database
  Store get lawndart => _database.lawndart;

  /// Lawndart database is open
  bool get lawnIsOpen => _database.lawnIsOpen;

  /// Wilt database
  Wilt get wilt => _database.wilt;

  bool _online = true;

  /// Initialise sporran
  Future<bool> initialise() async {
    await _database.initialise();

    // Online/offline listeners
    EventHandler goOffline() {
      _online = false;
      return null;
    }

    window.ononline = _transitionToOnline();
    window.onoffline = (goOffline());

    return true;
  }

  /// On/Offline indicator
  bool get online {
    // If we are not online or we are and the CouchDb database is not
    // available we are offline.
    if ((!_online) || (_database.noCouchDb)) {
      return false;
    }
    return true;
  }

  set online(bool state) {
    _online = state;
    if (state) {
      _transitionToOnline();
    }
  }

  /// Pending delete queue size
  int get pendingDeleteSize => _database.pendingLength();

  /// Ready event
  Stream<dynamic>? get onReady => _database.onReady;

  /// Manual notification control
  bool get manualNotificationControl => _database.manualNotificationControl;

  /// Get the JSON success response from an API operation result.
  JsonObjectLite getJsonResponse(JsonObjectLite result) {
    final JsonObjectLite response = JsonObjectLite();
    JsonObjectLite.toTypedJsonObjectLite(
        (result as dynamic).jsonCouchResponse, response);
    return response;
  }

  /// Start change notification manually
  void startChangeNotifications() {
    if (manualNotificationControl) {
      if (_database.wilt.changeNotificationsPaused) {
        _database.wilt.restartChangeNotifications();
      } else {
        _database.startChangeNotifications();
      }
    }
  }

  /// Stop change notification manually
  void stopChangeNotifications() {
    if (manualNotificationControl) {
      _database.wilt.pauseChangeNotifications();
    }
  }

  /// Manual control of sync().
  ///
  /// Usually Sporran syncs when a transition to online is detected,
  /// however this can be disabled, use in conjunction with manual
  /// change notification control. If this is set to false you must
  /// call sync() explicitly.
  bool autoSync = true;

  /// Online transition
  EventHandler _transitionToOnline() {
    _online = true;

    // If we have never connected to CouchDb try now,
    // otherwise we can sync straight away.

    if (!_database.noCouchDb) {
      _database.connectToCouch(true);
    }

    if (autoSync) {
      sync();
    }
    return null;
  }

  /// Update document.
  ///
  /// If the document does not exist a create is performed.
  ///
  /// For an update operation a specific revision must be specified.
  /// If the parameters are invalid null is returned.
  Future<SporranResult> put(String id, JsonObjectLite<dynamic> document,
      [String rev = '']) async {
    final document1 = JsonObjectLite();
    JsonObjectLite.toTypedJsonObjectLite(document, document1);
    final opCompleter = Completer<SporranResult>();
    if (id.isEmpty) {
      throw ArgumentError('Empty id supplied', id);
    }
    // Update LawnDart
    await _database.updateLocalStorageObject(
        id, document, rev, _SporranDatabase.notUpdatedc);

    // If we are offline just return
    if (!online) {
      final res = SporranResult();
      res.localResponse = true;
      res.operation = putc;
      res.ok = true;
      res.payload = document1;
      res.id = id;
      res.rev = rev;
      opCompleter.complete(res);
      return opCompleter.future;
    } else {
      // Do the put.
      final wiltRev = rev.isNotEmpty ? rev : null;
      dynamic res = await _database.wilt.putDocument(id, document1, wiltRev);
      // If success, mark the update as UPDATED in local storage.
      res.ok = false;
      res.localResponse = false;
      res.operation = putc;
      res.id = id;
      res.payload = document1;
      if (!res.error) {
        res.rev = res.jsonCouchResponse.rev;
        _database.updateLocalStorageObject(
            id, document, rev, _SporranDatabase.updatedc);
        _database.updateAttachmentRevisions(id, rev);
        res.ok = true;
      } else {
        res.rev = null;
      }
      opCompleter.complete(SporranResult.fromJsonObject(res));
    }

    return opCompleter.future;
  }

  /// Get a document
  /// If the parameters are invalid null is returned.
  Future<SporranResult> get(String id, [String rev = '']) async {
    final opCompleter = Completer<SporranResult>();
    if (id.isEmpty) {
      throw ArgumentError('Empty id supplied', id);
    }
    // Check for offline, if so try the get from local storage.
    if (!online) {
      final document = await _database.getLocalStorageObject(id);
      final dynamic res = JsonObjectLite<dynamic>();
      res.localResponse = true;
      res.operation = getc;
      res.id = id;
      res.rev = null;
      if (document == null) {
        res.ok = false;
        res.payload = null;
      } else {
        res.ok = true;
        res.payload = document['payload'];
        res.rev = WiltUserUtils.getDocumentRev(res);
      }
      opCompleter.complete(SporranResult.fromJsonObject(res));
      return opCompleter.future;
    } else {
      // Get the document from CouchDb with its attachments.
      final wiltRev = rev.isNotEmpty ? rev : null;
      dynamic res = await _database.wilt.getDocument(id, wiltRev, true);
      // If Ok update local storage with the document.
      res.operation = getc;
      res.id = id;
      res.localResponse = false;
      if (!res.error) {
        res.rev = WiltUserUtils.getDocumentRev(res.jsonCouchResponse);
        await _database.updateLocalStorageObject(
            id, res.jsonCouchResponse, res.rev, _SporranDatabase.updatedc);
        res.ok = true;
        res.payload = res.jsonCouchResponse;
        // Get the documents attachments and create them locally.
        _database.createDocumentAttachments(id, res.payload);
      } else {
        res.ok = false;
        res.payload = null;
        res.rev = null;
      }
      opCompleter.complete(SporranResult.fromJsonObject(res));
      return opCompleter.future;
    }
  }

  /// Delete a document.
  ///
  /// Revision must be supplied if we are online.
  /// If the parameters are invalid null is returned.
  Future<SporranResult> delete(String id, [String rev = '']) async {
    final opCompleter = Completer<SporranResult>();
    if (id.isEmpty) {
      throw ArgumentError('Empty id supplied', id);
    }
    // Remove from Lawndart //
    final document = await _database.lawndart.getByKey(id);
    if (document != null) {
      await _database.lawndart.removeByKey(id);
      // Check for offline, if so add to the pending delete queue
      // and return.
      if (!online) {
        _database.addPendingDelete(id, document);
        final dynamic res = JsonObjectLite<dynamic>();
        res.localResponse = true;
        res.operation = deletec;
        res.ok = true;
        res.id = id;
        res.payload = null;
        res.rev = rev;
        opCompleter.complete(SporranResult.fromJsonObject(res));
        return opCompleter.future;
      } else {
        // Delete the document from CouchDB.
        final wiltRev = rev.isNotEmpty ? rev : null;
        dynamic res = await _database.wilt.deleteDocument(id, wiltRev);
        res.operation = deletec;
        res.localResponse = false;
        res.payload = res.jsonCouchResponse;
        res.id = id;
        res.rev = null;
        if (res.error) {
          res.ok = false;
        } else {
          res.ok = true;
          res.rev = res.jsonCouchResponse.rev;
        }
        _database.removePendingDelete(id);
        opCompleter.complete(SporranResult.fromJsonObject(res));
      }
    } else {
      // Doesn't exist, return error.
      final dynamic res = JsonObjectLite<dynamic>();
      res.localResponse = true;
      res.operation = deletec;
      res.id = id;
      res.payload = null;
      res.rev = null;
      res.ok = false;
      opCompleter.complete(SporranResult.fromJsonObject(res));
    }

    return opCompleter.future;
  }

  /// Put attachment
  ///
  /// If the revision is supplied the attachment to the document
  /// will be updated, otherwise the attachment will be created, along with
  /// the document if needed.
  ///
  /// The JsonObjectLite attachment parameter must contain the following :-
  ///
  /// String attachmentName
  /// String rev - maybe '', see above
  /// String contentType - mime type in the form 'image/png'
  /// String payload - stringified binary blob.
  /// If the parameters are invalid null is returned.
  Future<SporranResult> putAttachment(String id, dynamic attachment) async {
    final opCompleter = Completer<SporranResult>();
    if (id.isEmpty) {
      throw ArgumentError('Empty id supplied', id);
    }
    if (attachment == null) {
      throw ArgumentError('Null attachment supplied for ', attachment);
    }
    // Update LawnDart.
    final key = '$id-${attachment.attachmentName}-'
        '${_SporranDatabase.attachmentMarkerc}';
    await _database.updateLocalStorageObject(
        key, attachment, attachment.rev, _SporranDatabase.notUpdatedc);
    // If we are offline just return //
    if (!online) {
      final dynamic res = JsonObjectLite<dynamic>();
      res.localResponse = true;
      res.operation = putAttachmentc;
      res.ok = true;
      res.payload = attachment;
      res.id = id;
      res.rev = null;
      opCompleter.complete(SporranResult.fromJsonObject(res));
      return opCompleter.future;
    } else {
      // Do the create.
      dynamic res;
      if (attachment.rev == '') {
        res = await _database.wilt.createAttachment(
            id,
            attachment.attachmentName,
            attachment.rev,
            attachment.contentType,
            attachment.payload);
      } else {
        res = await _database.wilt.updateAttachment(
            id,
            attachment.attachmentName,
            attachment.rev,
            attachment.contentType,
            attachment.payload);
      }
      // If success, mark the update as UPDATED in local storage.
      res.ok = false;
      res.localResponse = false;
      res.id = id;
      res.operation = putAttachmentc;
      res.rev = null;
      res.payload = null;
      if (!res.error) {
        final dynamic newAttachment =
            JsonObjectLite<dynamic>.fromJsonString(_mapToJson(attachment));
        newAttachment.contentType = attachment.contentType;
        newAttachment.payload = attachment.payload;
        newAttachment.attachmentName = attachment.attachmentName;
        res.payload = newAttachment;
        res.rev = res.jsonCouchResponse.rev;
        newAttachment.rev = res.jsonCouchResponse.rev;
        await _database.updateLocalStorageObject(key, newAttachment,
            res.jsonCouchResponse.rev, _SporranDatabase.updatedc);
        _database.updateAttachmentRevisions(id, res.jsonCouchResponse.rev);
        res.ok = true;
      }
      opCompleter.complete(SporranResult.fromJsonObject(res));
      return opCompleter.future;
    }
  }

  /// Delete an attachment.
  /// Revision can be null if offline.
  /// If the parameters are invalid null is returned.
  Future<SporranResult> deleteAttachment(String id, String attachmentName,
      [String rev = '']) async {
    final opCompleter = Completer<SporranResult>();
    if (id.isEmpty) {
      throw ArgumentError('Empty id supplied', id);
    }
    if (attachmentName.isEmpty) {
      throw ArgumentError('Empty attachment name supplied', attachmentName);
    }
    final key = '$id-$attachmentName-${_SporranDatabase.attachmentMarkerc}';

    // Remove from Lawndart.
    final document = await _database.lawndart.getByKey(key);
    if (document != null) {
      await _database.lawndart.removeByKey(key);
      // Check for offline, if so add to the pending delete
      // queue and return.
      if (!online) {
        _database.addPendingDelete(key, document);
        final dynamic res = JsonObjectLite<dynamic>();
        res.localResponse = true;
        res.operation = deleteAttachmentc;
        res.ok = true;
        res.id = id;
        res.payload = null;
        res.rev = null;
        opCompleter.complete(SporranResult.fromJsonObject(res));
        return opCompleter.future;
      } else {
        _database.removePendingDelete(key);
        // Delete the attachment from CouchDB.
        final wiltRev = rev.isNotEmpty ? rev : null;
        dynamic res =
            await _database.wilt.deleteAttachment(id, attachmentName, wiltRev);
        res.operation = deleteAttachmentc;
        res.localResponse = false;
        res.payload = res.jsonCouchResponse;
        res.id = id;
        res.rev = null;
        if (res.error) {
          res.ok = false;
        } else {
          res.ok = true;
          res.rev = res.jsonCouchResponse.rev;
        }
        opCompleter.complete(SporranResult.fromJsonObject(res));
        return opCompleter.future;
      }
    } else {
      // Doesn't exist, return error.
      final dynamic res = JsonObjectLite<dynamic>();
      res.localResponse = true;
      res.operation = deleteAttachmentc;
      res.id = id;
      res.payload = null;
      res.rev = null;
      res.ok = false;
      opCompleter.complete(SporranResult.fromJsonObject(res));
    }

    return opCompleter.future;
  }

  /// Get an attachment.
  /// If the parameters are invalid null is returned.
  Future<SporranResult> getAttachment(String id, String attachmentName) async {
    final opCompleter = Completer<SporranResult>();
    if (id.isEmpty) {
      throw ArgumentError('Empty id supplied', id);
    }
    if (attachmentName.isEmpty) {
      throw ArgumentError('Empty attachment name supplied', attachmentName);
    }

    final key = '$id-$attachmentName-${_SporranDatabase.attachmentMarkerc}';

    // Check for offline, if so try the get from local storage.
    if (!online) {
      final document = await _database.getLocalStorageObject(key);
      final dynamic res = JsonObjectLite<dynamic>();
      res.localResponse = true;
      res.id = id;
      res.rev = null;
      res.operation = getAttachmentc;
      if (document == null) {
        res.ok = false;
        res.payload = null;
      } else {
        res.ok = true;
        res.payload = document;
      }
      opCompleter.complete(SporranResult.fromJsonObject(res));
      return opCompleter.future;
    } else {
      var res = await _database.wilt.getAttachment(id, attachmentName);
      // If Ok update local storage with the attachment.
      res.operation = getAttachmentc;
      res.id = id;
      res.localResponse = false;
      res.rev = '';

      if (!res.error) {
        final dynamic successResponse = res.jsonCouchResponse;

        res.ok = true;
        final dynamic attachment = JsonObjectLite<dynamic>();
        attachment.attachmentName = attachmentName;
        attachment.contentType = successResponse.contentType;
        attachment.payload = res.responseText;
        attachment.rev = res.rev;
        res.payload = attachment;

        await _database.updateLocalStorageObject(
            key, attachment, res.rev, _SporranDatabase.updatedc);
      } else {
        res.ok = false;
        res.payload = null;
      }
      opCompleter.complete(SporranResult.fromJsonObject(res));
    }

    return opCompleter.future;
  }

  /// Bulk document create.
  ///
  /// docList is a map of documents with their keys.
  /// If the parameters are invalid null is returned.
  Future<SporranResult> bulkCreate(
      Map<String, JsonObjectLite<dynamic>> docList) async {
    final opCompleter = Completer<SporranResult>();
    if (docList.isEmpty) {
      throw ArgumentError('Empty docList supplied');
    }

    // Update LawnDart.
    for (final key in docList.keys) {
      await _database.updateLocalStorageObject(
          key, docList[key]!, '', _SporranDatabase.notUpdatedc);
    }

    // If we are offline just return.
    if (!online) {
      final dynamic res = JsonObjectLite<dynamic>();
      res.localResponse = true;
      res.operation = bulkCreatec;
      res.ok = true;
      res.payload = docList;
      res.id = null;
      res.rev = null;
      opCompleter.complete(SporranResult.fromJsonObject(res));
      return opCompleter.future;
    } else {
      // Prepare the documents //
      final documentList = <String>[];
      docList.forEach((dynamic key, dynamic document) {
        final docString = WiltUserUtils.addDocumentId(document, key);
        documentList.add(docString);
      });

      final docs = WiltUserUtils.createBulkInsertString(documentList);
      // Do the bulk create//
      var res = await _database.wilt.bulkString(docs);
      // If success, mark the update as UPDATED in local storage //
      res.ok = false;
      res.localResponse = false;
      res.operation = bulkCreatec;
      res.id = null;
      res.payload = docList;
      res.rev = null;
      if (!res.error) {
        // Get the revisions for the updates.
        final JsonObjectLite<dynamic> couchResp = getJsonResponse(res);
        final revisions = <JsonObjectLite<dynamic>?>[];
        final revisionsMap = <String, String>{};

        for (final dynamic resp in couchResp.toList()) {
          try {
            revisions.add(resp);
            revisionsMap[resp.id] = resp['rev'];
          } on Exception {
            revisions.add(null);
          }
        }
        res.rev = revisions;

        // Update the documents.
        docList.forEach((String key, dynamic document) async {
          await _database.updateLocalStorageObject(
              key, document, revisionsMap[key]!, _SporranDatabase.updatedc);
        });

        res.ok = true;
      }

      opCompleter.complete(SporranResult.fromJsonObject(res));
    }

    return opCompleter.future;
  }

  /// Get all documents.
  ///
  /// The parameters should be self explanatory and are additive.
  ///
  /// In offline mode only the keys parameter is respected.
  /// The includeDocs parameter is also forced to true.
  Future<SporranResult> getAllDocs(
      {bool includeDocs = false,
      int limit = 10,
      String? startKey,
      String? endKey,
      List<String> keys = const <String>[],
      bool descending = false}) async {
    final opCompleter = Completer<SporranResult>();

    // Check for offline, if so try the get from local storage.
    if (!online) {
      if (keys.isEmpty) {
        // Get all the keys from Lawndart.
        _database.lawndart.keys().toList().then((dynamic keyList) async {
          /* Only return documents */
          final docList = <String>[];
          keyList.forEach((dynamic key) {
            final List<String> temp = key.split('-');
            if ((temp.length == 3) &&
                (temp[2] == _SporranDatabase.attachmentMarkerc)) {
              /* Attachment, discard the key */
            } else {
              docList.add(key);
            }
          });
          var documents = await _database.getLocalStorageObjects(docList);
          final dynamic res = JsonObjectLite<dynamic>();
          res.localResponse = true;
          res.operation = getAllDocsc;
          res.id = null;
          res.rev = null;
          res.ok = true;
          res.payload = documents;
          res.totalRows = documents.length;
          res.keyList = documents.keys.toList();
          opCompleter.complete(SporranResult.fromJsonObject(res));
        });
      } else {
        final documents = await _database.getLocalStorageObjects(keys);
        final dynamic res = JsonObjectLite<dynamic>();
        res.localResponse = true;
        res.operation = getAllDocsc;
        res.id = null;
        res.rev = null;
        res.ok = true;
        res.payload = documents;
        res.totalRows = documents.length;
        res.keyList = documents.keys.toList();
        opCompleter.complete(SporranResult.fromJsonObject(res));
        return opCompleter.future;
      }
    } else {
      // Get the document from CouchDb.
      var res = await _database.wilt.getAllDocs(
          includeDocs: includeDocs,
          limit: limit,
          startKey: startKey,
          endKey: endKey,
          keys: keys.isEmpty ? null : keys,
          descending: descending);
      // If Ok update local storage with the document.
      res.operation = getAllDocsc;
      res.id = null;
      res.rev = null;
      res.localResponse = false;
      if (!res.error) {
        res.ok = true;
        res.payload = res.jsonCouchResponse;
      } else {
        res.localResponse = false;
        res.ok = false;
        res.payload = null;
      }
      opCompleter.complete(SporranResult.fromJsonObject(res));
      return opCompleter.future;
    }

    return opCompleter.future;
  }

  /// Get information about the database.
  ///
  /// When offline the a list of the keys in the Lawndart database are returned,
  /// otherwise a response for CouchDb is returned.
  Future<SporranResult> getDatabaseInfo() async {
    final opCompleter = Completer<SporranResult>();

    // Check for offline, if so try the get from local storage.
    if (!online) {
      final keys = await _database.lawndart.keys().toList();
      final dynamic res = JsonObjectLite<dynamic>();
      res.localResponse = true;
      res.operation = dbInfoc;
      res.id = null;
      res.rev = null;
      res.payload = keys;
      res.ok = true;
      opCompleter.complete(SporranResult.fromJsonObject(res));
    } else {
      // Get the database information from CouchDb.
      var res = await _database.wilt.getDatabaseInfo();
      // If Ok update local storage with the database info //
      res.operation = dbInfoc;
      res.id = null;
      res.rev = null;
      res.localResponse = false;
      if (!res.error) {
        res.ok = true;
        res.payload = res.jsonCouchResponse;
      } else {
        res.localResponse = false;
        res.ok = false;
        res.payload = null;
      }
      opCompleter.complete(SporranResult.fromJsonObject(res));
    }

    return opCompleter.future;
  }

  /// Synchronise local storage and CouchDb when we come online or on demand.
  ///
  /// Note we don't check for failures in this, there is nothing we
  /// can really do if we say get a conflict error or a not exists error
  /// on an update or delete.
  ///
  /// For updates, if applied successfully we wait for the change
  /// notification to arrive to mark the update as UPDATED. Note if these
  /// are switched off sync may be lost with Couch.
  void sync() {
    // Only if we are online.
    if (!online) {
      return;
    }
    _database.sync();
  }

  /// Login
  ///
  /// Allows log in credentials to be changed if needed.
  void login(String user, String password) {
    if (user.isNotEmpty) {
      _database.login(user, password);
    } else {
      throw SporranException(SporranException.invalidLoginCredsEx);
    }
  }

  /// Serialize a map to a JSON string
  static String _mapToJson(dynamic map) {
    if (map is String) {
      try {
        json.decode(map);
        return map;
      } on Exception {
        return '';
      }
    }
    return json.encode(map);
  }
}
