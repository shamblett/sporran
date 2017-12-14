/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 * 
 * Sporran is a pouchdb alike for Dart.
 * 
 * This is the main Sporran API class.
 * 
 * Please read the usage and interface documentation supplied for
 * further details.
 * 
 */

part of sporran;

class Sporran {
  /// Method constants
  static final String putc = "put";
  static final String getc = "get";
  static final String deletec = "delete";
  static final String putAttachmentc = "put_attachment";
  static final String getAttachmentc = "get_attachment";
  static final String deleteAttachmentc = "delete_attachment";
  static final String bulkCreatec = "bulk_create";
  static final String getAllDocsc = "get_all_docs";
  static final String dbInfoc = "db_info";

  /// Construction.
  ///
  Sporran(SporranInitialiser initialiser) {
    if (initialiser == null) {
      throw new SporranException(SporranException.noInitialiserEx);
    }

    this._dbName = initialiser.dbName;

    /**
     * Construct our database.
     */
    _database = new _SporranDatabase(
        _dbName,
        initialiser.hostname,
        initialiser.manualNotificationControl,
        initialiser.port,
        initialiser.scheme,
        initialiser.username,
        initialiser.password,
        initialiser.preserveLocal);

    /**
     * Online/offline listeners
     */
    window.onOnline.listen((_) => _transitionToOnline());
    window.onOffline.listen((_) => _online = false);
  }

  /// Database
  _SporranDatabase _database;

  /// Database name
  String _dbName;
  String get dbName => _dbName;

  /// Lawndart database
  Store get lawndart => _database.lawndart;

  /// Lawndart databse is open
  bool get lawnIsOpen => _database.lawnIsOpen;

  /// Wilt database
  Wilt get wilt => _database.wilt;

  /// On/Offline indicator
  bool _online = true;
  bool get online {
    /* If we are not online or we are and the CouchDb database is not
     * available we are offline
     */
    if ((!_online) || (_database.noCouchDb)) return false;
    return true;
  }

  set online(bool state) {
    _online = state;
    if (state) _transitionToOnline();
  }

  /// Completion function
  var _clientCompleter;

  set clientCompleter(JsonObjectLite completer) => _clientCompleter = completer;

  /// Response getter for completion callbacks
  JsonObjectLite _completionResponse;

  JsonObjectLite get completionResponse => _completionResponse;

  /// Pending delete queue size
  int get pendingDeleteSize => _database.pendingLength();

  /// Ready event
  Stream get onReady => _database.onReady;

  /// Manual notification control
  bool get manualNotificationControl => _database.manualNotificationControl;

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
    if (manualNotificationControl) _database.wilt.pauseChangeNotifications();
  }

  /// Manual control of sync().
  ///
  /// Usually Sporran syncs when a transition to online is detected,
  /// however this can be disabled, use in conjunction with manual
  /// change notification control. If this is set to false you must
  /// call sync() explicitly.
  bool _autoSync = true;
  bool get autoSync => _autoSync;
  set autoSync(bool state) => _autoSync = state;

  /// Raise an exception from a future API call.
  /// If we are using completion throw an exception as normal.
  Future<SporranException> _raiseException(String name) {
    if (_clientCompleter == null) {
      return new Future.error(new SporranException(name));
    } else {
      throw new SporranException(name);
    }
  }

  /// Online transition
  void _transitionToOnline() {
    _online = true;

    /**
     * If we have never connected to CouchDb try now,
     * otherwise we can sync straight away
     */
    if (_database.noCouchDb) {
      _database.connectToCouch(true);
    } else {
      if (_autoSync) sync();
    }
  }

  /// Common completion response creator for all databases
  JsonObjectLite _createCompletionResponse(JsonObjectLite result) {
    final JsonObjectLite completion = new JsonObjectLite();

    completion.operation = result.operation;
    completion.payload = result.payload;
    completion.localResponse = result.localResponse;
    completion.id = result.id;
    completion.rev = result.rev;

    /**
     * Check for a local or Wilt response
     */
    if (result.localResponse) {
      completion.ok = result.ok;
    } else {
      if (result.error) {
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

  /// Update document.
  ///
  /// If the document does not exist a create is performed.
  ///
  /// For an update operation a specific revision must be specified.
  Future put(String id, JsonObjectLite document, [String rev = null]) {
    final Completer opCompleter = new Completer();

    if (id == null) {
      return _raiseException(SporranException.putNoDocIdEx);
    }

    /* Update LawnDart */
    _database.updateLocalStorageObject(
        id, document, rev, _SporranDatabase.notUpdatedc)
      ..then((_) {
        /* If we are offline just return */
        if (!online) {
          final JsonObjectLite res = new JsonObjectLite();
          res.localResponse = true;
          res.operation = putc;
          res.ok = true;
          res.payload = document;
          res.id = id;
          res.rev = rev;

          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
          return opCompleter.future;
        }

        /* Complete locally, then boomerang to the client */
        void completer(JsonObjectLite res) {
          /* If success, mark the update as UPDATED in local storage */
          res.ok = false;
          res.localResponse = false;
          res.operation = putc;
          res.id = id;
          res.payload = document;
          if (!res.error) {
            res.rev = res.jsonCouchResponse.rev;
            _database.updateLocalStorageObject(
                id, document, rev, _SporranDatabase.updatedc);
            _database.updateAttachmentRevisions(id, rev);

            res.ok = true;
          } else {
            res.rev = null;
          }

          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
        }

        /* Do the put */
        _database.wilt.putDocument(id, document, rev)
          ..then((res) {
            completer(res);
          });
      });

    return opCompleter.future;
  }

  /// Get a document
  Future get(String id, [String rev = null]) {
    final Completer opCompleter = new Completer();

    if (id == null) {
      return _raiseException(SporranException.getNoDocIdEx);
    }

    /* Check for offline, if so try the get from local storage */
    if (!online) {
      _database.getLocalStorageObject(id)
        ..then((JsonObjectLite document) {
          final JsonObjectLite res = new JsonObjectLite();
          res.localResponse = true;
          res.operation = getc;
          res.id = id;
          res.rev = null;
          if (document.isEmpty) {
            res.ok = false;
            res.payload = null;
          } else {
            res.ok = true;
            res.payload = document['payload'];
            res.rev = WiltUserUtils.getDocumentRev(res);
          }

          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
        });
    } else {
      void completer(JsonObjectLite res) {
        /* If Ok update local storage with the document */
        res.operation = getc;
        res.id = id;
        res.localResponse = false;
        if (!res.error) {
          res.rev = WiltUserUtils.getDocumentRev(res.jsonCouchResponse);
          _database.updateLocalStorageObject(
              id, res.jsonCouchResponse, res.rev, _SporranDatabase.updatedc);
          res.ok = true;
          res.payload = res.jsonCouchResponse;
          /**
           * Get the documents attachments and create them locally
           */
          _database.createDocumentAttachments(id, res.payload);
        } else {
          res.ok = false;
          res.payload = null;
          res.rev = null;
        }

        opCompleter.complete(res);
        if (_clientCompleter != null) {
          _completionResponse = _createCompletionResponse(res);
          _clientCompleter();
        }
      }

      /* Get the document from CouchDb with its attachments */
      _database.wilt.getDocument(id, rev, true)
        ..then((res) {
          completer(res);
        });
    }

    return opCompleter.future;
  }

  /// Delete a document.
  ///
  /// Revision must be supplied if we are online
  Future delete(String id, [String rev = null]) {
    final Completer opCompleter = new Completer();

    if (id == null) {
      return _raiseException(SporranException.deleteNoDocIdEx);
    }

    /* Remove from Lawndart */
    _database.lawndart.getByKey(id)
      ..then((String document) {
        if (document != null) {
          _database.lawndart.removeByKey(id)
            ..then((_) {
              /* Check for offline, if so add to the pending delete queue and return */
              if (!online) {
                _database.addPendingDelete(id, document);
                final JsonObjectLite res = new JsonObjectLite();
                res.localResponse = true;
                res.operation = deletec;
                res.ok = true;
                res.id = id;
                res.payload = null;
                res.rev = null;
                opCompleter.complete(res);
                if (_clientCompleter != null) {
                  _completionResponse = _createCompletionResponse(res);
                  _clientCompleter();
                }
                return opCompleter.future;
              } else {
                /* Online, delete from CouchDb */
                void completer(JsonObjectLite res) {
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
                  opCompleter.complete(res);
                  if (_clientCompleter != null) {
                    _completionResponse = _createCompletionResponse(res);
                    _clientCompleter();
                  }
                }

                /* Delete the document from CouchDB */
                _database.wilt.deleteDocument(id, rev)
                  ..then((res) {
                    completer(res);
                  });
              }
            });
        } else {
          /* Doesnt exist, return error */
          final JsonObjectLite res = new JsonObjectLite();
          res.localResponse = true;
          res.operation = deletec;
          res.id = id;
          res.payload = null;
          res.rev = null;
          res.ok = false;
          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
        }
      });

    return opCompleter.future;
  }

  /// Put attachment
  ///
  /// If the revision is supplied the attachment to the document will be updated,
  /// otherwise the attachment will be created, along with the document if needed.
  ///
  /// The JsonObjectLite attachment parameter must contain the following :-
  ///
  /// String attachmentName
  /// String rev - maybe '', see above
  /// String contentType - mime type in the form 'image/png'
  /// String payload - stringified binary blob
  Future putAttachment(String id, JsonObjectLite attachment) {
    final Completer opCompleter = new Completer();

    if (id == null) {
      return _raiseException(SporranException.putAttNoDocIdEx);
    }

    if (attachment == null) {
      return _raiseException(SporranException.putAttNoAttEx);
    }

    /* Update LawnDart */
    final String key =
        "$id-${attachment.attachmentName}-${_SporranDatabase.attachmentMarkerc}";
    _database.updateLocalStorageObject(
        key, attachment, attachment.rev, _SporranDatabase.notUpdatedc)
      ..then((_) {
        /* If we are offline just return */
        if (!online) {
          final JsonObjectLite res = new JsonObjectLite();
          res.localResponse = true;
          res.operation = putAttachmentc;
          res.ok = true;
          res.payload = attachment;
          res.id = id;
          res.rev = null;
          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
          return opCompleter.future;
        }

        /* Complete locally, then boomerang to the client */
        void completer(JsonObjectLite res) {
          /* If success, mark the update as UPDATED in local storage */
          res.ok = false;
          res.localResponse = false;
          res.id = id;
          res.operation = putAttachmentc;
          res.rev = null;
          res.payload = null;

          if (!res.error) {
            final JsonObjectLite newAttachment = new JsonObjectLite.fromMap(
                attachment);
            newAttachment.contentType = attachment.contentType;
            newAttachment.payload = attachment.payload;
            newAttachment.attachmentName = attachment.attachmentName;
            res.payload = newAttachment;
            res.rev = res.jsonCouchResponse.rev;
            newAttachment.rev = res.jsonCouchResponse.rev;
            _database.updateLocalStorageObject(key, newAttachment,
                res.jsonCouchResponse.rev, _SporranDatabase.updatedc);
            _database.updateAttachmentRevisions(id, res.jsonCouchResponse.rev);
            res.ok = true;
          }
          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
        }

        /* Do the create */
        if (attachment.rev == '') {
          _database.wilt.createAttachment(id, attachment.attachmentName,
              attachment.rev, attachment.contentType, attachment.payload)
            ..then((res) {
              completer(res);
            });
        } else {
          _database.wilt.updateAttachment(id, attachment.attachmentName,
              attachment.rev, attachment.contentType, attachment.payload)
            ..then((res) {
              completer(res);
            });
        }
      });

    return opCompleter.future;
  }

  /// Delete an attachment.
  /// Revision can be null if offline
  Future deleteAttachment(String id, String attachmentName, String rev) {
    final Completer opCompleter = new Completer();
    final String key =
        "$id-$attachmentName-${_SporranDatabase.attachmentMarkerc}";

    if (id == null) {
      return _raiseException(SporranException.deleteAttNoDocIdEx);
    }

    if (attachmentName == null) {
      return _raiseException(SporranException.deleteAttNoAttNameEx);
    }

    if ((online) && (rev == null)) {
      return _raiseException(SporranException.deleteAttNoRevEx);
    }

    /* Remove from Lawndart */
    _database.lawndart.getByKey(key)
      ..then((document) {
        if (document != null) {
          _database.lawndart.removeByKey(key)
            ..then((_) {
              /* Check for offline, if so add to the pending delete queue and return */
              if (!online) {
                _database.addPendingDelete(key, document);
                final JsonObjectLite res = new JsonObjectLite();
                res.localResponse = true;
                res.operation = deleteAttachmentc;
                res.ok = true;
                res.id = id;
                res.payload = null;
                res.rev = null;
                opCompleter.complete(res);
                if (_clientCompleter != null) {
                  _completionResponse = _createCompletionResponse(res);
                  _clientCompleter();
                }
                return opCompleter.future;
              } else {
                /* Online, delete from CouchDb */
                void completer(JsonObjectLite res) {
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
                  _database.removePendingDelete(key);
                  opCompleter.complete(res);
                  if (_clientCompleter != null) {
                    _completionResponse = _createCompletionResponse(res);
                    _clientCompleter();
                  }
                }

                /* Delete the attachment from CouchDB */
                _database.wilt.deleteAttachment(id, attachmentName, rev)
                  ..then((res) {
                    completer(res);
                  });
              }
            });
        } else {
          /* Doesnt exist, return error */
          final JsonObjectLite res = new JsonObjectLite();
          res.localResponse = true;
          res.operation = deleteAttachmentc;
          res.id = id;
          res.payload = null;
          res.rev = null;
          res.ok = false;
          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
        }
      });

    return opCompleter.future;
  }

  /// Get an attachment
  Future getAttachment(String id, String attachmentName) {
    final Completer opCompleter = new Completer();
    final String key =
        "$id-$attachmentName-${_SporranDatabase.attachmentMarkerc}";

    if (id == null) {
      return _raiseException(SporranException.getAttNoDocIdEx);
    }

    if (attachmentName == null) {
      return _raiseException(SporranException.getAttNoAttNameEx);
    }

    /* Check for offline, if so try the get from local storage */
    if (!online) {
      _database.getLocalStorageObject(key)
        ..then((JsonObjectLite document) {
          final JsonObjectLite res = new JsonObjectLite();
          res.localResponse = true;
          res.id = id;
          res.rev = null;
          res.operation = getAttachmentc;
          if (document.isEmpty) {
            res.ok = false;
            res.payload = null;
          } else {
            res.ok = true;
            res.payload = document;
          }

          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
          return opCompleter.future;
        });
    } else {
      void completer(JsonObjectLite res) {
        /* If Ok update local storage with the attachment */
        res.operation = getAttachmentc;
        res.id = id;
        res.localResponse = false;
        res.rev = null;

        if (!res.error) {
          final JsonObjectLite successResponse = res.jsonCouchResponse;

          res.ok = true;
          final JsonObjectLite attachment = new JsonObjectLite();
          attachment.attachmentName = attachmentName;
          attachment.contentType = successResponse.contentType;
          attachment.payload = res.responseText;
          attachment.rev = res.rev;
          res.payload = attachment;

          _database.updateLocalStorageObject(
              key, attachment, res.rev, _SporranDatabase.updatedc);
        } else {
          res.ok = false;
          res.payload = null;
        }

        opCompleter.complete(res);
        if (_clientCompleter != null) {
          _completionResponse = _createCompletionResponse(res);
          _clientCompleter();
        }
      }

      /* Get the attachment from CouchDb */
      _database.wilt.getAttachment(id, attachmentName)
        ..then((res) {
          completer(res);
        });
    }

    return opCompleter.future;
  }

  /// Bulk document create.
  ///
  /// docList is a map of documents with their keys
  Future bulkCreate(Map<String, JsonObjectLite> docList) {
    final Completer opCompleter = new Completer();

    if (docList == null) {
      return _raiseException(SporranException.bulkCreateNoDocListEx);
    }

    /* Futures list for LawnDart update */
    final List<Future> updateList = new List<Future>();

    /* Update LawnDart */
    docList.forEach((key, document) {
      updateList.add(_database.updateLocalStorageObject(
          key, document, null, _SporranDatabase.notUpdatedc));
    });

    /* Wait for Lawndart */
    Future.wait(updateList)
      ..then((_) {
        /* If we are offline just return */
        if (!online) {
          final JsonObjectLite res = new JsonObjectLite();
          res.localResponse = true;
          res.operation = bulkCreatec;
          res.ok = true;
          res.payload = docList;
          res.id = null;
          res.rev = null;
          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
          return opCompleter.future;
        }

        /* Complete locally, then boomerang to the client */
        void completer(JsonObjectLite res) {
          /* If success, mark the update as UPDATED in local storage */
          res.ok = false;
          res.localResponse = false;
          res.operation = bulkCreatec;
          res.id = null;
          res.payload = docList;
          res.rev = null;
          if (!res.error) {
            /* Get the revisions for the updates */
            final JsonObjectLite couchResp = res.jsonCouchResponse;
            final List revisions = new List<JsonObjectLite>();
            final Map revisionsMap = new Map<String, String>();

            couchResp.toList().forEach((resp) {
              try {
                revisions.add(resp);
                revisionsMap[resp.id] = resp.rev;
              } catch (e) {
                revisions.add(null);
              }
            });
            res.rev = revisions;

            /* Update the documents */
            docList.forEach((key, document) {
              _database.updateLocalStorageObject(
                  key, document, revisionsMap[key], _SporranDatabase.updatedc);
            });

            res.ok = true;
          }

          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
        }

        /* Prepare the documents */
        final List documentList = new List<String>();
        docList.forEach((key, document) {
          final String docString = WiltUserUtils.addDocumentId(document, key);
          documentList.add(docString);
        });

        final String docs = WiltUserUtils.createBulkInsertString(documentList);

        /* Do the bulk create*/
        _database.wilt.bulkString(docs)
          ..then((res) {
            completer(res);
          });
      });

    return opCompleter.future;
  }

  /// Get all documents.
  ///
  /// The parameters should be self explanatory and are addative.
  ///
  /// In offline mode only the keys parameter is respected.
  /// The includeDocs parameter is also forced to true.
  Future<JsonObjectLite> getAllDocs(
      {bool includeDocs: false,
      int limit: null,
      String startKey: null,
      String endKey: null,
      List<String> keys: null,
      bool descending: false}) {
    final Completer opCompleter = new Completer();

    /* Check for offline, if so try the get from local storage */
    if (!online) {
      if (keys == null) {
        /* Get all the keys from Lawndart */
        _database.lawndart.keys().toList()
          ..then((keyList) {
            /* Only return documents */
            final List<String> docList = new List();
            keyList.forEach((key) {
              final List temp = key.split('-');
              if ((temp.length == 3) &&
                  (temp[2] == _SporranDatabase.attachmentMarkerc)) {
                /* Attachment, discard the key */

              } else {
                docList.add(key);
              }
            });

            _database.getLocalStorageObjects(docList)
              ..then((documents) {
                final JsonObjectLite res = new JsonObjectLite();
                res.localResponse = true;
                res.operation = getAllDocsc;
                res.id = null;
                res.rev = null;
                if (documents == null) {
                  res.ok = false;
                  res.payload = null;
                } else {
                  res.ok = true;
                  res.payload = documents;
                  res.totalRows = documents.length;
                  res.keyList = documents.keys.toList();
                }

                opCompleter.complete(res);
                if (_clientCompleter != null) {
                  _completionResponse = _createCompletionResponse(res);
                  _clientCompleter();
                }
              });
          });
      } else {
        _database.getLocalStorageObjects(keys)
          ..then((documents) {
            final JsonObjectLite res = new JsonObjectLite();
            res.localResponse = true;
            res.operation = getAllDocsc;
            res.id = null;
            res.rev = null;
            if (documents == null) {
              res.ok = false;
              res.payload = null;
            } else {
              res.ok = true;
              res.payload = documents;
              res.totalRows = documents.length;
              res.keyList = documents.keys.toList();
            }

            opCompleter.complete(res);
            if (_clientCompleter != null) {
              _completionResponse = _createCompletionResponse(res);
              _clientCompleter();
            }
          });
      }
    } else {
      void completer(JsonObjectLite res) {
        /* If Ok update local storage with the document */
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

        opCompleter.complete(res);
        if (_clientCompleter != null) {
          _completionResponse = _createCompletionResponse(res);
          _clientCompleter();
        }
      }

      /* Get the document from CouchDb */
      _database.wilt.getAllDocs(
          includeDocs: includeDocs,
          limit: limit,
          startKey: startKey,
          endKey: endKey,
          keys: keys,
          descending: descending)
        ..then((res) {
          completer(res);
        });
    }

    return opCompleter.future;
  }

  /// Get information about the database.
  ///
  /// When offline the a list of the keys in the Lawndart database are returned,
  /// otherwise a response for CouchDb is returned.
  Future<JsonObjectLite> getDatabaseInfo() {
    final Completer opCompleter = new Completer();

    if (!online) {
      _database.lawndart.keys().toList()
        ..then((List keys) {
          final JsonObjectLite res = new JsonObjectLite();
          res.localResponse = true;
          res.operation = dbInfoc;
          res.id = null;
          res.rev = null;
          res.payload = keys;
          res.ok = true;
          opCompleter.complete(res);
          if (_clientCompleter != null) {
            _completionResponse = _createCompletionResponse(res);
            _clientCompleter();
          }
        });
    } else {
      void completer(JsonObjectLite res) {
        /* If Ok update local storage with the database info */
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

        opCompleter.complete(res);
        if (_clientCompleter != null) {
          _completionResponse = _createCompletionResponse(res);
          _clientCompleter();
        }
      }

      /* Get the database information from CouchDb */
      _database.wilt.getDatabaseInfo()
        ..then((res) {
          completer(res);
        });
    }

    return opCompleter.future;
  }

  /// Synchronise local storage and CouchDb when we come online or on demand.
  ///
  /// Note we don't check for failures in this, there is nothing we can really do
  /// if we say get a conflict error or a not exists error on an update or delete.
  ///
  /// For updates, if applied successfully we wait for the change notification to
  /// arrive to mark the update as UPDATED. Note if these are switched off sync may be
  /// lost with Couch.
  void sync() {
    /* Only if we are online */
    if (!online) return;

    _database.sync();
  }

  /// Login
  ///
  /// Allows log in credentials to be changed if needed.
  void login(String user, String password) {
    if (user == null || password == null) {
      throw new SporranException(SporranException.invalidLoginCredsEx);
    }

    _database.login(user, password);
  }
}
