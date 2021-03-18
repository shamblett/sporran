/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */

part of sporran;

/// Sporran exceptions
class SporranException implements Exception {
  SporranException([this._message = 'No Message Supplied']);

  /* Exception message strings */
  static const String headerEx = 'SporranException: ';
  static const String lawnNotInitEx =
      'Initialisation Failure, Lawndart is not initialized';
  static const String invalidLoginCredsEx =
      'Invalid login credentials - user and password must be supplied';
  static const String noInitialiserEx =
      'You must supply an initialiser on construction';

  final String _message;

  @override
  String toString() => '$headerEx$_message';
}
