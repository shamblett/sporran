/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */

part of sporran;

class SporranException implements Exception {

  String _message = 'No Message Supplied';
  SporranException([this._message]);

  String toString() => "SporranException: message = ${_message}";

}
