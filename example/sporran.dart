/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 17/09/2018
 * Copyright :  S.Hamblett
 */

import 'package:sporran/sporran.dart';
import 'package:json_object_lite/json_object_lite.dart';
import '../test/lib/sporran_test_config.dart';

/// An example of sporran initialisation and usage, see the test scenarios for more detailed
/// use cases.
void main() async {
  // Initialise Sporran
  final SporranInitialiser initialiser = new SporranInitialiser();
  initialiser.dbName = databaseName;
  initialiser.hostname = hostName;
  initialiser.manualNotificationControl = true;
  initialiser.port = port;
  initialiser.scheme = scheme;
  initialiser.username = userName;
  initialiser.password = userPassword;
  initialiser.preserveLocal = false;

  // Create the client
  final Sporran sporran = new Sporran(initialiser);
  sporran.autoSync = false;
  await sporran.onReady.first;

  /// Put a document
  final dynamic onlineDoc = new JsonObjectLite();
  final String docIdPutOnline = "putOnlineg3";
  onlineDoc.name = "Online";
  await sporran.put(docIdPutOnline, onlineDoc);

  /// Get it
  sporran.get(docIdPutOnline)
    ..then((res) {
      final dynamic payload = new JsonObjectLite.fromJsonString(res.payload);
      print(payload.payload.name);
    });

  /// Get it offline
  sporran.online = false;
  sporran.get(docIdPutOnline)
    ..then((res) {
      final dynamic payload = new JsonObjectLite.fromJsonString(res.payload);
      print(payload.payload.name);
    });
}
