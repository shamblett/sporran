/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */

part of sporran;

class SporranException implements Exception {
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

  String _message = 'No Message Supplied';
  SporranException([this._message]);

  String toString() => headerEx + "${_message}";
}
