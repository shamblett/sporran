/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */

part of sporran;

// ignore_for_file: public_member_api_docs

/// Sporran exceptions
class SporranException implements Exception {
  SporranException([this._message = 'No Message Supplied']);

  /* Exception message strings */
  static const String headerEx = 'SporranException: ';
  static const String putNoDocIdEx = 'put() expects a document id';
  static const String getNoDocIdEx = 'get() expects a document id';
  static const String deleteNoDocIdEx = 'delete() expects a document id';
  static const String putAttNoDocIdEx = 'putAttachment() expects a document id';
  static const String putAttNoAttEx = 'putAttachment() expects an attachment';
  static const String deleteAttNoDocIdEx =
      'deleteAttachment() expects a document id';
  static const String deleteAttNoAttNameEx =
      'deleteAttachment() expects an attachment name';
  static const String deleteAttNoRevEx =
      'deleteAttachment() expects a revision';
  static const String getAttNoDocIdEx = 'getAttachment() expects a document id';
  static const String getAttNoAttNameEx =
      'getAttachment() expects an attachment name';
  static const String bulkCreateNoDocListEx =
      'bulkCreate() expects a document list';
  static const String lawnNotInitEx =
      'Initialisation Failure, Lawndart is not initialized';
  static const String invalidLoginCredsEx =
      'Invalid login credentials - user and password must be supplied';
  static const String noInitialiserEx =
      'You must supply an initialiser on construction';

  // ignore: unnecessary_final
  final String _message;

  @override
  String toString() => '$headerEx$_message';
}
