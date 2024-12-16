/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 17/09/2018
 * Copyright :  S.Hamblett
 */

import 'package:sporran/sporran.dart';
import 'package:json_object_lite/json_object_lite.dart';
import 'package:wilt/wilt.dart';

// ignore: avoid_relative_lib_imports
import './sporran_example_config.dart';

/// An example of sporran initialisation and usage, see the test
/// scenarios for more detailed use cases.
void main() async {
  // Initialise Sporran
  final initialiser = SporranInitialiser();
  initialiser.dbName = databaseName;
  initialiser.hostname = hostName;
  initialiser.manualNotificationControl = true;
  initialiser.port = port;
  initialiser.scheme = scheme;
  initialiser.username = userName;
  initialiser.password = userPassword;
  initialiser.preserveLocal = false;

  // Delete any existing test databases
  final deleter = Wilt(hostName);
  deleter.login(userName, userPassword);
  await deleter.deleteDatabase(databaseName);

  // Create the client, and initialise it
  final sporran = Sporran(initialiser)..initialise();
  sporran.autoSync = false;
  // Wait for ready
  await sporran.onReady!.first;

  // Put a document
  final dynamic onlineDoc = JsonObjectLite<dynamic>();
  const docIdPutOnline = 'putOnlineg3';
  onlineDoc.name = 'Online';
  await sporran.put(docIdPutOnline, onlineDoc);

  // Get it
  dynamic res = await sporran.get(docIdPutOnline);
  dynamic payload = JsonObjectLite();
  JsonObjectLite.toTypedJsonObjectLite(res.payload, payload);
  print(payload['name']);

  // Get it offline
  sporran.online = false;
  dynamic res2 = await sporran.get(docIdPutOnline);
  final dynamic payload2 = JsonObjectLite<dynamic>.fromJsonString(res2.payload);
  print(payload2['payload']['name']);
}
