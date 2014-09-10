import 'dart:async';

import 'package:sporran/sporran.dart';
import 'package:json_object/json_object.dart';
import 'sporran_test_config.dart';
import 'package:unittest/unittest.dart';

main() {

  Sporran sporran;

  String docIdPutOnline = "putOnlineg3";
  String docIdPutOffline = "putOfflineg3";
  JsonObject onlineDoc = new JsonObject();
  JsonObject offlineDoc = new JsonObject();
  String onlineDocRev;

  var wrapper1 = () {

    if (sporran.lawnIsOpen) {

      var docwrapper = (res) {

        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT);
        expect(res.localResponse, isFalse);
        expect(res.id, docIdPutOnline);
        expect(res.rev, anything);
        onlineDocRev = res.rev;
        expect(res.payload.name, "Online");

      };

      onlineDoc.name = "Online";
      sporran.put(docIdPutOnline, onlineDoc)..then((res) {
            docwrapper(res);
          });

    }

  };

  var wrapper = () {

    sporran.online = true;
    Timer timer = new Timer(new Duration(seconds: 3), wrapper1);

  };

  SporranInitialiser initialiser = new SporranInitialiser();
  initialiser.dbName = databaseName;
  initialiser.hostname = hostName;
  initialiser.manualNotificationControl = true;
  initialiser.port = port;
  initialiser.scheme = scheme;
  initialiser.username = userName;
  initialiser.password = userPassword;
  initialiser.preserveLocal = false;
  sporran = new Sporran(initialiser);
  sporran.autoSync = false;
  sporran.onReady.first.then((e) => wrapper());


}
