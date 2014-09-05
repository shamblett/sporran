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

  /**
   * Constants
   */
  static final PUT = "put";
  static final GET = "get";
  static final DELETE = "delete";
  static final PUT_ATTACHMENT = "put_attachment";
  static final GET_ATTACHMENT = "get_attachment";
  static final DELETE_ATTACHMENT = "delete_attachment";
  static final BULK_CREATE = "bulk_create";
  static final GET_ALL_DOCS = "get_all_docs";
  static final DB_INFO = "db_info";


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
    if ((!_online) || (_database.noCouchDb)) return false;
    return true;

  }
  set online(bool state) {

    _online = state;
    if (state) _transitionToOnline();

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

    if (manualNotificationControl) {

      if (_database.wilt.changeNotificationsPaused) {

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

    if (manualNotificationControl) _database.wilt.pauseChangeNotifications();
  }

  /**
   * Manual control of sync().
   * 
   * Usually Sporran syncs when a transition to online is detected,
   * however this can be disabled, use in conjunction with manual 
   * change notification control. If this is set to false you must
   * call sync() explicitly.
   */
  bool _autoSync = true;
  bool get autoSync => _autoSync;
  set autoSync(bool state) => _autoSync = state;

  /**
   * Construction.
   * 
   */
  Sporran(this._dbName, String hostName, [bool manualNotificationControl = false, String port = "5984", String scheme = "http://", String userName = null, String password = null]) {


    /**
     * Construct our database.
     */
    _database = new _SporranDatabase(_dbName, hostName, manualNotificationControl, port, scheme, userName, password);

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
    if (_database.noCouchDb) {

      _database.connectToCouch(true);

    } else {

      if (_autoSync) sync();

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


  /**
   * Update document.
   * 
   * If the document does not exist a create is performed.
   * 
   * For an update operation a specific revision must be specified.
   */
  Future<JsonObject> put(String id, JsonObject document, [String rev = null]) {

    Completer opCompleter = new Completer();

    /* Update LawnDart */
    _database.updateLocalStorageObject(id, document, rev, _SporranDatabase.NOT_UPDATED)..then((_) {


          /* If we are offline just return */
          if (!online) {

            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.operation = PUT;
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
          void completer(res) {

            /* If success, mark the update as UPDATED in local storage */
            res.ok = false;
            res.localResponse = false;
            res.operation = PUT;
            res.id = id;
            res.payload = document;
            if (!res.error) {

              res.rev = res.jsonCouchResponse.rev;
              _database.updateLocalStorageObject(id, document, rev, _SporranDatabase.UPDATED);
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
          ;

          /* Do the put */
          _database.wilt.putDocument(id, document, rev)..then((res) {
                completer(res);
              });
        });

    return opCompleter.future;

  }

  /**
   * Get a document 
   */
  Future<JsonObject> get(String id, [String rev = null]) {

    Completer opCompleter = new Completer();

    /* Check for offline, if so try the get from local storage */
    if (!online) {

      _database.getLocalStorageObject(id)..then((document) {

            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.operation = GET;
            res.id = id;
            res.rev = null;
            if (document.isEmpty) {

              res.ok = false;
              res.payload = null;

            } else {

              res.ok = true;
              res.payload = new JsonObject.fromMap(document['payload']);
              res.rev = WiltUserUtils.getDocumentRev(res.payload);

            }

            opCompleter.complete(res);
            if (_clientCompleter != null) {
              _completionResponse = _createCompletionResponse(res);
              _clientCompleter();
            }

          });


    } else {

      void completer(res) {

        /* If Ok update local storage with the document */
        res.operation = GET;
        res.id = id;
        res.localResponse = false;
        if (!res.error) {

          res.rev = WiltUserUtils.getDocumentRev(res.jsonCouchResponse);
          _database.updateLocalStorageObject(id, res.jsonCouchResponse, res.rev, _SporranDatabase.UPDATED);
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
      ;

      /* Get the document from CouchDb with its attachments */
      _database.wilt.getDocument(id, rev, true)..then((res) {
            completer(res);
          });

    }

    return opCompleter.future;

  }

  /**
   * Delete a document.
   * 
   * Revision must be supplied if we are online
   */
  Future<JsonObject> delete(String id, [String rev = null]) {

    Completer opCompleter = new Completer();

    /* Remove from Lawndart */
    _database.lawndart.getByKey(id)..then((document) {

          if (document != null) {

            _database.lawndart.removeByKey(id)..then((_) {

                  /* Check for offline, if so add to the pending delete queue and return */
                  if (!online) {

                    _database.addPendingDelete(id, document);
                    JsonObject res = new JsonObject();
                    res.localResponse = true;
                    res.operation = DELETE;
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
                    void completer(res) {

                      res.operation = DELETE;
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
                    _database.wilt.deleteDocument(id, rev)..then((res) {
                          completer(res);
                        });

                  }

                });

          } else {

            /* Doesnt exist, return error */
            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.operation = DELETE;
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
  Future<JsonObject> putAttachment(String id, JsonObject attachment) {

    Completer opCompleter = new Completer();

    /* Update LawnDart */
    String key = "$id-${attachment.attachmentName}-${_SporranDatabase.ATTACHMENTMARKER}";
    _database.updateLocalStorageObject(key, attachment, attachment.rev, _SporranDatabase.NOT_UPDATED)..then((_) {


          /* If we are offline just return */
          if (!online) {

            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.operation = PUT_ATTACHMENT;
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
          void completer(res) {

            /* If success, mark the update as UPDATED in local storage */
            res.ok = false;
            res.localResponse = false;
            res.id = id;
            res.operation = PUT_ATTACHMENT;
            res.rev = null;
            res.payload = null;

            if (!res.error) {

              JsonObject newAttachment = new JsonObject.fromMap(attachment);
              newAttachment.contentType = attachment.contentType;
              newAttachment.payload = attachment.payload;
              newAttachment.attachmentName = attachment.attachmentName;
              res.payload = newAttachment;
              res.rev = res.jsonCouchResponse.rev;
              newAttachment.rev = res.jsonCouchResponse.rev;
              _database.updateLocalStorageObject(key, newAttachment, res.jsonCouchResponse.rev, _SporranDatabase.UPDATED);
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

            _database.wilt.createAttachment(id, attachment.attachmentName, attachment.rev, attachment.contentType, attachment.payload)..then((res) {
                  completer(res);
                });

          } else {

            _database.wilt.updateAttachment(id, attachment.attachmentName, attachment.rev, attachment.contentType, attachment.payload)..then((res) {
                  completer(res);
                });

          }
        });

    return opCompleter.future;

  }

  /**
    * Delete an attachment.
    * 
    * Revision can be null if offline
    */
  Future<JsonObject> deleteAttachment(String id, String attachmentName, String rev) {

    Completer opCompleter = new Completer();
    String key = "$id-$attachmentName-${_SporranDatabase.ATTACHMENTMARKER}";

    /* Remove from Lawndart */
    _database.lawndart.getByKey(key)..then((document) {

          if (document != null) {

            _database.lawndart.removeByKey(key)..then((_) {

                  /* Check for offline, if so add to the pending delete queue and return */
                  if (!online) {

                    _database.addPendingDelete(key, document);
                    JsonObject res = new JsonObject();
                    res.localResponse = true;
                    res.operation = DELETE_ATTACHMENT;
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
                    void completer(res) {

                      res.operation = DELETE_ATTACHMENT;
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
                    _database.wilt.deleteAttachment(id, attachmentName, rev)..then((res) {
                          completer(res);
                        });

                  }

                });

          } else {

            /* Doesnt exist, return error */
            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.operation = DELETE_ATTACHMENT;
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

  /**
    * Get an attachment
    */
  Future<JsonObject> getAttachment(String id, String attachmentName) {

    Completer opCompleter = new Completer();
    String key = "$id-$attachmentName-${_SporranDatabase.ATTACHMENTMARKER}";

    /* Check for offline, if so try the get from local storage */
    if (!online) {

      _database.getLocalStorageObject(key)..then((document) {

            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.id = id;
            res.rev = null;
            res.operation = GET_ATTACHMENT;
            if (document.isEmpty) {

              res.ok = false;
              res.payload = null;

            } else {

              res.ok = true;
              res.payload = new JsonObject.fromMap(document['payload']);

            }

            opCompleter.complete(res);
            if (_clientCompleter != null) {
              _completionResponse = _createCompletionResponse(res);
              _clientCompleter();
            }
            return opCompleter.future;

          });

    } else {

      void completer(res) {

        /* If Ok update local storage with the attachment */
        res.operation = GET_ATTACHMENT;
        res.id = id;
        res.localResponse = false;
        res.rev = null;

        if (!res.error) {

          JsonObject successResponse = res.jsonCouchResponse;

          res.ok = true;
          JsonObject attachment = new JsonObject();
          attachment.attachmentName = attachmentName;
          attachment.contentType = successResponse.contentType;
          attachment.payload = res.responseText;
          attachment.rev = res.rev;
          res.payload = attachment;

          _database.updateLocalStorageObject(key, attachment, res.rev, _SporranDatabase.UPDATED);

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
      ;

      /* Get the attachment from CouchDb */
      _database.wilt.getAttachment(id, attachmentName)..then((res) {
            completer(res);
          });

    }

    return opCompleter.future;


  }

  /**
    * Bulk document create.
    * 
    * docList is a map of documents with their keys
    */
  Future<JsonObject> bulkCreate(Map<String, JsonObject> docList) {


    Completer opCompleter = new Completer();

    /* Futures list for LawnDart update */
    List<Future> updateList = new List<Future>();

    /* Update LawnDart */
    docList.forEach((key, document) {

      updateList.add(_database.updateLocalStorageObject(key, document, null, _SporranDatabase.NOT_UPDATED));

    });

    /* Wait for Lawndart */
    Future.wait(updateList)..then((_) {

          /* If we are offline just return */
          if (!online) {

            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.operation = BULK_CREATE;
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
          void completer(res) {

            /* If success, mark the update as UPDATED in local storage */
            res.ok = false;
            res.localResponse = false;
            res.operation = BULK_CREATE;
            res.id = null;
            res.payload = docList;
            res.rev = null;
            if (!res.error) {

              /* Get the revisions for the updates */
              JsonObject couchResp = res.jsonCouchResponse;
              List revisions = new List<JsonObject>();
              Map revisionsMap = new Map<String, String>();

              couchResp.forEach((JsonObject resp) {

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

                _database.updateLocalStorageObject(key, document, revisionsMap[key], _SporranDatabase.UPDATED);
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
          List documentList = new List<String>();
          docList.forEach((key, document) {

            String docString = WiltUserUtils.addDocumentId(document, key);
            documentList.add(docString);

          });

          String docs = WiltUserUtils.createBulkInsertString(documentList);

          /* Do the bulk create*/
          _database.wilt.bulkString(docs)..then((res) {
                completer(res);
              });
          
        });
    
    return opCompleter.future;

  }

  /**
    * Get all documents.
    * 
    * The parameters should be self explanatory and are addative.
    *
    * In offline mode only the keys parameter is respected. 
    * The includeDocs parameter is also forced to true.
    */
  Future<JsonObject> getAllDocs({bool includeDocs: false, int limit: null, String startKey: null, String endKey: null, List<String> keys: null, bool descending: false}) {

    Completer opCompleter = new Completer();

    /* Check for offline, if so try the get from local storage */
    if (!online) {

      _database.getLocalStorageObjects(keys)..then((documents) {

            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.operation = GET_ALL_DOCS;
            res.id = null;
            res.rev = null;
            if (documents == null) {

              res.ok = false;
              res.payload = null;

            } else {

              res.ok = true;
              res.payload = documents;

            }

            opCompleter.complete(res);
            if (_clientCompleter != null) {
              _completionResponse = _createCompletionResponse(res);
              _clientCompleter();
            }


          });


    } else {

      void completer(res) {

        /* If Ok update local storage with the document */
        res.operation = GET_ALL_DOCS;
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
      ;

      /* Get the document from CouchDb */
      _database.wilt.getAllDocs(includeDocs: includeDocs, limit: limit, startKey: startKey, endKey: endKey, keys: keys, descending: descending)..then((res) {
            completer(res);
          });

    }

    return opCompleter.future;

  }

  /**
    * Get information about the database.
    * 
    * When offline the a list of the keys in the Lawndart database are returned, 
    * otherwise a response for CouchDb is returned.
    */
  Future<JsonObject> getDatabaseInfo() {

    Completer opCompleter = new Completer();

    if (!online) {

      _database.lawndart.keys().toList()..then((List keys) {

            JsonObject res = new JsonObject();
            res.localResponse = true;
            res.operation = DB_INFO;
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


      void completer(res) {

        /* If Ok update local storage with the database info */
        res.operation = DB_INFO;
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
      ;

      /* Get the database information from CouchDb */
      _database.wilt.getDatabaseInfo()..then((res) {
            completer(res);
          });

    }

    return opCompleter.future;

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
    if (!online) return;

    _database.sync();

  }

}
