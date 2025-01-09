//
// Package : Sporran
// Author : S. Hamblett <steve.hamblett@linux.com>
// Date   : 09/01/2025
// Copyright :  S.Hamblett
//
// Sporran is a pouchdb alike for Dart.
//
//

part of '../sporran.dart';

/// When an API method is invoked [Sporran] will supply a completion
/// result [SporranResult] with the following properties.
class SporranResult {

  /// Default
  SporranResult();

  /// Create from a [JsonObjectLite]
  SporranResult.fromJsonObject(dynamic res) {
    id = res.id;
    operation = res.operation;
    localResponse = res.localResponse;
    ok = res.ok;
    if (!ok) {
      res.containsKey['errorCode'] ? errorCode = res.errorCode : 0;
      res.containsKey['errorText'] ? errorText = res.errorText : '';
      res.containsKey['errorReason'] ? errorReason = res.errorReason : '';
    }
    res.rev ?? '';
    res.containsKey['payload'] ? payload = res.payload : null;
  }

  /// Always present, the id of the document.
  String id = '';

  /// Always present, the operation performed, one of the defined operation
  /// constants, e.g [Sporran.putc].
  String operation = Sporran.none;

  /// Always present, true indicates the response was generated whilst offline,
  /// false indicates online.
  bool localResponse = false;

  /// Always present, indicates if true the result of the operation was OK, if false
  /// it wasn't. If false and [localResponse] is true no other information is given. If
  /// [localResponse] is false(online) the following error properties are set :-
  ///
  ///      [errorCode]
  ///      [errorText]
  ///      [errorReason]
  ///      indicating the error as reported by CouchDb.
  bool ok = false;

  int errorCode = 0;

  String errorText = '';

  String errorReason = '';

  /// Always present, indicates the revision of the document post this operation,
  /// may be empty for bulk operations and database info etc and if ok is false or
  /// we are not online.
  String rev = '';

  /// Always present if [ok] is true, the document or attachment body.
  /// If [ok] is false this will be null.
  /// It will also be null for offline [Sporran.deletec] operations.
  ///
  /// In the case of an online [Sporran.bulkCreatec] this will contain the bulk insert
  /// response from CouchDb, if offline it will contain the supplied document list.
  ///
  /// For the [Sporran.dbInfoc] operation] if offline this will contain a list of
  /// local storage document keys. If online the CouchDb response.
  ///
  /// For [Sporran.getAllDocsc] this will contain a list of retrieved documents from
  /// either local storage or CouchDb.
  ///
  /// Note the document body may well contain CouchDb annotations such as
  /// _attachments, _rev etc. These can be interrogated if needed.
  JsonObjectLite? payload;
}
