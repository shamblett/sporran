/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */

part of sporran;

class SporranException implements Exception {

  /* Exception message strings */
  static const HEADER = 'SporranException: ';
  static const PUT_NO_DOC_ID ='put() expects a document id';
  static const GET_NO_DOC_ID ='get() expects a document id';
  static const DELETE_NO_DOC_ID ='delete() expects a document id';
  static const PUT_ATT_NO_DOC_ID ='putAttachment() expects a document id';
  static const PUT_ATT_NO_ATT ='putAttachment() expects an attachment';
  static const DELETE_ATT_NO_DOC_ID ='deleteAttachment() expects a document id';
  static const DELETE_ATT_NO_ATT_NAME ='deleteAttachment() expects an attachment name';
  static const DELETE_ATT_NO_REV ='deleteAttachment() expects a revision';
  static const GET_ATT_NO_DOC_ID ='getAttachment() expects a document id';
  static const GET_ATT_NO_ATT_NAME ='getAttachment() expects an attachment name';
  static const BULK_CREATE_NO_DOCLIST ='bulkCreate() expects a document list';
  static const LAWN_NOT_INIT = 'Initialisation Failure, Lawndart is not initialized';
  
  String _message = 'No Message Supplied';
  SporranException([this._message]);

  String toString() => HEADER + "${_message}";

}
