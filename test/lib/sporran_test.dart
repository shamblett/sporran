/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */
@TestOn('browser')

import 'dart:async';
import 'dart:html';

import 'package:sporran/sporran.dart';
import 'package:json_object_lite/json_object_lite.dart';
import 'package:wilt/wilt.dart';
import 'package:test/test.dart';
import 'sporran_test_config.dart';

void logMessage(String message) {
  window.console.log(message);
  print(message);
}

void main() async {
  /* Common initialiser */
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

  /* Group 1 - Environment tests */
  group('1. Environment Tests - ', () {
    var status = 'online';

    test('Online/Offline', () {
      window.onOffline.first.then((dynamic e) {
        expect(status, 'offline');
        /* Because we aren't really offline */
        expect(window.navigator.onLine, isTrue);
      });

      window.onOnline.first.then((dynamic e) {
        expect(status, 'online');
        expect(window.navigator.onLine, isTrue);
      });

      status = 'offline';
      dynamic e = Event.eventType('Event', 'offline');
      window.dispatchEvent(e);
      status = 'online';
      e = Event.eventType('Event', 'online');
      window.dispatchEvent(e);
    });
  }, skip: false);

  /* Group 2 - Sporran constructor/ invalid parameter tests */
  group('2. Constructor/Invalid Parameter Tests - ', () {
    Sporran? sporran;

    test('0. Sporran Initialisation', () {
      sporran = Sporran(initialiser);

      final dynamic wrapper = expectAsync0(() {
        expect(sporran, isNotNull);
        expect(sporran!.dbName, databaseName);
        expect(sporran!.online, true);
      });

      sporran!.autoSync = false;
      sporran!.onReady!.first.then((dynamic e) => wrapper());
    });

    test('1. Construction Online/Offline listener ', () {
      Sporran? sporran21;

      final dynamic wrapper = expectAsync0(() {
        final offline = Event.eventType('Event', 'offline');
        window.dispatchEvent(offline);
        expect(sporran21!.online, isFalse);
        final online = Event.eventType('Event', 'online');
        window.dispatchEvent(online);
      });

      Timer? pause;

      final dynamic wrapper1 = expectAsync1((Timer pause) {
        expect(sporran21!.online, isTrue);
        sporran21 = null;
      });

      sporran21 = Sporran(initialiser);
      sporran21!.autoSync = false;
      sporran21!.onReady!.first.then((dynamic e) => wrapper());
      pause = Timer(const Duration(seconds: 2), () {
        wrapper1(pause);
      });
    });

    test('2. Construction Existing Database ', () {
      Sporran? sporran22 = Sporran(initialiser);

      final dynamic wrapper = expectAsync0(() {
        expect(sporran22, isNotNull);
        expect(sporran22!.dbName, databaseName);
        sporran22 = null;
      });

      sporran22!.autoSync = false;
      sporran22!.onReady!.first.then((dynamic e) => wrapper());
    });

    test('3. Construction Invalid Authentication ', () {
      initialiser.password = 'none';
      Sporran? sporran23 = Sporran(initialiser);
      initialiser.password = userPassword;

      final dynamic wrapper = expectAsync0(() {
        expect(sporran23, isNotNull);
        expect(sporran23!.dbName, databaseName);
        sporran23 = null;
      });

      sporran23!.autoSync = false;
      sporran23!.onReady!.first.then((dynamic e) => wrapper());
    });

    test('4. Put No Doc Id ', () {
      sporran!.put('', JsonObjectLite<dynamic>()).then((final res) {
        expect(res, isNull);
      });
    });

    test('5. Get No Doc Id ', () {
      sporran!.get('', '').then((final res) {
        expect(res, isNull);
      });
    });

    test('6. Delete No Doc Id ', () {
      sporran!.delete('', '').then((var res) {
        expect(res, isNull);
      });
    });

    test('7. Put Attachment No Doc Id ', () {
      sporran!.putAttachment('', null).then((final res) {
        expect(res, isNull);
      });
    });

    test('8. Put Attachment No Attachment ', () {
      sporran!.putAttachment('billy', null).then((final res) {
        expect(res, isNull);
      });
    });

    test('9. Delete Attachment No Doc Id ', () {
      sporran!.deleteAttachment('', '', '').then((final res) {
        expect(res, isNull);
      });
    });

    test('10. Delete Attachment No Attachment Name ', () {
      sporran!.deleteAttachment('billy', '', '').then((final res) {
        expect(res, isNull);
      });
    });

    test('12. Get Attachment No Doc Id ', () {
      sporran!.getAttachment('', '').then((final res) {
        expect(res, isNull);
      });
    });

    test('13. Get Attachment No Attachment Name ', () {
      sporran!.getAttachment('billy', '').then((final res) {
        expect(res, isNull);
      });
    });

    test('14. Bulk Create No Document List ', () {
      sporran!
          .bulkCreate(<String, JsonObjectLite<dynamic>>{}).then((final res) {
        expect(res, isNull);
      });
    });

    test('15. Login invalid user ', () {
      try {
        sporran!.login('', 'password');
      } on SporranException catch (e) {
        expect(e.runtimeType.toString(), 'SporranException');
        expect(e.toString(),
            SporranException.headerEx + SporranException.invalidLoginCredsEx);
      }
    });
  });

  /* Group 3 - Sporran document put/get tests */
  group('3. Document Put/Get/Delete Tests - ', () {
    late Sporran sporran3;

    const docIdPutOnline = 'putOnlineg3';
    const docIdPutOffline = 'putOfflineg3';
    final dynamic onlineDoc = JsonObjectLite<dynamic>();
    final dynamic offlineDoc = JsonObjectLite<dynamic>();
    var onlineDocRev = '';

    test('1. Create and Open Sporran', () {
      final dynamic wrapper1 = expectAsync0(() {
        expect(sporran3.lawnIsOpen, isTrue);
      });

      final dynamic wrapper = expectAsync0(() {
        expect(sporran3.dbName, databaseName);
        Timer(const Duration(seconds: 3), wrapper1);
      });

      sporran3 = Sporran(initialiser);
      sporran3.autoSync = false;
      sporran3.onReady!.first.then((dynamic e) => wrapper());
    });

    test('2. Put Document Online docIdPutOnline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putc);
        expect(res.localResponse, isFalse);
        expect(res.id, docIdPutOnline);
        expect(res.rev, anything);
        onlineDocRev = res.rev;
        expect(res.payload.name, 'Online');
      });

      sporran3.online = true;
      onlineDoc.name = 'Online';
      sporran3.put(docIdPutOnline, onlineDoc).then(wrapper);
    });

    test('3. Put Document Offline docIdPutOffline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putc);
        expect(res.localResponse, isTrue);
        expect(res.id, docIdPutOffline);
        expect(res.payload.name, 'Offline');
      });

      sporran3.online = false;
      offlineDoc.name = 'Offline';
      sporran3.put(docIdPutOffline, offlineDoc).then(wrapper);
    });

    test('4. Put Document Online Conflict', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.errorCode, 409);
        expect(res.jsonCouchResponse.error, 'conflict');
        expect(res.operation, Sporran.putc);
        expect(res.id, docIdPutOnline);
      });

      sporran3.online = true;
      onlineDoc.name = 'Online';
      sporran3.put(docIdPutOnline, onlineDoc).then(wrapper);
    });

    test('5. Put Document Online Updated docIdPutOnline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putc);
        expect(res.localResponse, isFalse);
        expect(res.id, docIdPutOnline);
        expect(res.rev, anything);
        expect(res.payload.name, 'Online - Updated');
      });

      onlineDoc.name = 'Online - Updated';
      sporran3.put(docIdPutOnline, onlineDoc, onlineDocRev).then(wrapper);
    });

    test('6. Get Document Offline docIdPutOnline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isTrue);
        expect(res.id, docIdPutOnline);
        final dynamic payload =
            JsonObjectLite<dynamic>.fromJsonString(res.payload);
        expect(payload.payload.name, 'Online - Updated');
      });

      sporran3.online = false;
      sporran3.get(docIdPutOnline).then(wrapper);
    });

    test('7. Get Document Offline docIdPutOffline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isTrue);
        expect(res.id, docIdPutOffline);
        final dynamic payload =
            JsonObjectLite<dynamic>.fromJsonString(res.payload);
        expect(payload.payload.name, 'Offline');
        expect(res.rev, isNull);
      });

      sporran3.online = false;
      sporran3.get(docIdPutOffline).then(wrapper);
    });

    test('8. Get Document Offline Not Exist', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isTrue);
        expect(res.id, 'Billy');
        expect(res.rev, isNull);
        expect(res.payload, isNull);
      });

      sporran3.online = false;
      offlineDoc.name = 'Offline';
      sporran3.get('Billy').then(wrapper);
    });

    test('9. Get Document Online docIdPutOnline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.getc);
        expect(res.payload.name, 'Online - Updated');
        expect(res.localResponse, isFalse);
        expect(res.id, docIdPutOnline);
        onlineDocRev = res.rev;
      });

      sporran3.online = true;
      sporran3.get(docIdPutOnline).then(wrapper);
    });

    test('10. Delete Document Offline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.deletec);
        expect(res.id, docIdPutOffline);
        expect(res.payload, isNull);
        expect(res.rev, '');
        expect(sporran3.pendingDeleteSize, 1);
      });

      sporran3.online = false;
      sporran3.delete(docIdPutOffline).then(wrapper);
    });

    test('11. Delete Document Online', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.deletec);
        expect(res.id, docIdPutOnline);
        expect(res.payload, isNotNull);
        expect(res.rev, anything);
      });

      sporran3.online = true;
      sporran3.delete(docIdPutOnline, onlineDocRev).then(wrapper);
    });

    test('12. Get Document Online Not Exist', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isFalse);
        expect(res.id, 'Billy');
      });

      sporran3.get('Billy').then(wrapper);
    });

    test('13. Delete Document Not Exist', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.deletec);
        expect(res.id, 'Billy');
        expect(res.payload, isNull);
        expect(res.rev, isNull);
      });

      sporran3.online = false;
      sporran3.delete('Billy').then(wrapper);
    });

    test('14. Group Pause', () {
      final dynamic wrapper = expectAsync0(() {});
      Timer(const Duration(seconds: 3), wrapper);
    });
  }, skip: false);

  /* Group 4 - Sporran attachment put/get tests */
  group('4. Attachment Put/Get/Delete Tests - ', () {
    late Sporran sporran4;

    const docIdPutOnline = 'putOnlineg4';
    const docIdPutOffline = 'putOfflineg4';
    final dynamic onlineDoc = JsonObjectLite<dynamic>();
    final dynamic offlineDoc = JsonObjectLite<dynamic>();
    var onlineDocRev = '';

    const attachmentPayload =
        'iVBORw0KGgoAAAANSUhEUgAAABwAAAASCAMAAAB/2U7WAAAABlBMVEUAAAD///+l2Z/dAAAASUlEQVR4XqWQUQoAIAxC2/0vXZDrEX4IJTRkb7lobNUStXsB0jIXIAMSsQnWlsV+wULF4Avk9fLq2r8a5HSE35Q3eO2XP1A1wQkZSgETvDtKdQAAAABJRU5ErkJggg==';

    test('1. Create and Open Sporran', () {
      final dynamic wrapper = expectAsync0(() {
        expect(sporran4.dbName, databaseName);
        expect(sporran4.lawnIsOpen, isTrue);
      });

      sporran4 = Sporran(initialiser);

      sporran4.autoSync = false;
      sporran4.onReady!.first.then((dynamic e) => wrapper());
    });

    test('2. Put Document Online docIdPutOnline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putc);
        expect(res.id, docIdPutOnline);
        expect(res.localResponse, isFalse);
        expect(res.payload.name, 'Online');
        expect(res.rev, anything);
        onlineDocRev = res.rev;
      });

      sporran4.online = true;
      onlineDoc.name = 'Online';
      sporran4.put(docIdPutOnline, onlineDoc).then(wrapper);
    });

    test('3. Put Document Offline docIdPutOffline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putc);
        expect(res.id, docIdPutOffline);
        expect(res.localResponse, isTrue);
        expect(res.payload.name, 'Offline');
      });

      sporran4.online = false;
      offlineDoc.name = 'Offline';
      sporran4.put(docIdPutOffline, offlineDoc).then(wrapper);
    });

    test('4. Create Attachment Online docIdPutOnline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, docIdPutOnline);
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        onlineDocRev = res.rev;
        expect(res.payload.attachmentName, 'onlineAttachment');
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      sporran4.online = true;
      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'onlineAttachment';
      attachment.rev = onlineDocRev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran4.putAttachment(docIdPutOnline, attachment).then(wrapper);
    });

    test('5. Create Attachment Offline docIdPutOffline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, docIdPutOffline);
        expect(res.localResponse, isTrue);
        expect(res.rev, isNull);
        expect(res.payload.attachmentName, 'offlineAttachment');
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      sporran4.online = false;
      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'offlineAttachment';
      attachment.rev = onlineDocRev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran4.putAttachment(docIdPutOffline, attachment).then(wrapper);
    });

    test('6. Get Attachment Online docIdPutOnline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.getAttachmentc);
        expect(res.id, docIdPutOnline);
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        expect(res.payload.attachmentName, 'onlineAttachment');
        expect(res.payload.contentType, 'image/png; charset=utf-8');
        expect(res.payload.payload, attachmentPayload);
      });

      sporran4.online = true;
      sporran4.getAttachment(docIdPutOnline, 'onlineAttachment').then(wrapper);
    });

    test('7. Get Attachment Offline docIdPutOffline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.getAttachmentc);
        expect(res.id, docIdPutOffline);
        expect(res.localResponse, isTrue);
        expect(res.rev, isNull);
        final dynamic p2 =
            JsonObjectLite<dynamic>.fromJsonString(res.payload.payload);
        expect(p2.payload.attachmentName, 'offlineAttachment');
        expect(p2.payload.contentType, 'image/png');
        expect(p2.payload.payload, attachmentPayload);
      });

      sporran4.online = false;
      sporran4
          .getAttachment(docIdPutOffline, 'offlineAttachment')
          .then(wrapper);
    });

    test('8. Get Document Online docIdPutOnline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.getc);
        expect(res.id, docIdPutOnline);
        expect(res.localResponse, isFalse);
        expect(res.rev, onlineDocRev);
        final attachments = WiltUserUtils.getAttachments(res.payload);
        expect(attachments.length, 1);
      });

      sporran4.online = true;
      sporran4.get(docIdPutOnline, onlineDocRev).then(wrapper);
    });

    test('9. Delete Attachment Online docIdPutOnline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.deleteAttachmentc);
        expect(res.id, docIdPutOnline);
        expect(res.localResponse, isFalse);
        onlineDocRev = res.rev;
        expect(res.rev, anything);
      });

      sporran4.online = true;
      sporran4
          .deleteAttachment(docIdPutOnline, 'onlineAttachment', onlineDocRev)
          .then(wrapper);
    });

    test('10. Delete Document Online docIdPutOnline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {});

      /* Tidy up only, tested in group 3 */
      sporran4.delete(docIdPutOnline, onlineDocRev).then(wrapper);
    });

    test('11. Delete Attachment Offline docIdPutOffline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.deleteAttachmentc);
        expect(res.id, docIdPutOffline);
        expect(res.localResponse, isTrue);
        expect(res.rev, isNull);
        expect(res.payload, isNull);
      });

      sporran4.online = false;
      sporran4
          .deleteAttachment(docIdPutOffline, 'offlineAttachment', '')
          .then(wrapper);
    });

    test('12. Delete Attachment Not Exist', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.deleteAttachmentc);
        expect(res.id, docIdPutOffline);
        expect(res.localResponse, isTrue);
        expect(res.rev, isNull);
        expect(res.payload, isNull);
      });

      sporran4.online = false;
      sporran4.deleteAttachment(docIdPutOffline, 'Billy', '').then(wrapper);
    }, skip: false);
  });

  /* Group 5 - Sporran Bulk Documents tests */
  group('5. Bulk Document Tests - ', () {
    late Sporran sporran5;
    var docid1rev = '';
    var docid2rev = '';
    var docid3rev = '';

    test('1. Create and Open Sporran', () {
      final dynamic wrapper = expectAsync0(() {
        expect(sporran5.dbName, databaseName);
        expect(sporran5.lawnIsOpen, isTrue);
      });

      sporran5 = Sporran(initialiser);

      sporran5.autoSync = false;
      sporran5.onReady!.first.then((dynamic e) => wrapper());
    });

    test('2. Bulk Insert Documents Online', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.bulkCreatec);
        expect(res.id, isNull);
        expect(res.payload, isNotNull);
        expect(res.rev, isNotNull);
        expect(res.rev[0].rev, anything);
        docid1rev = res.rev[0].rev;
        expect(res.rev[1].rev, anything);
        docid2rev = res.rev[1].rev;
        expect(res.rev[2].rev, anything);
        docid3rev = res.rev[2].rev;
        final dynamic doc3 = res.payload['docid3'];
        expect(doc3.title, 'Document 3');
        expect(doc3.version, 3);
        expect(doc3.attribute, 'Doc 3 attribute');
      });

      final dynamic document1 = JsonObjectLite<dynamic>();
      document1.title = 'Document 1';
      document1.version = 1;
      document1.attribute = 'Doc 1 attribute';

      final dynamic document2 = JsonObjectLite<dynamic>();
      document2.title = 'Document 2';
      document2.version = 2;
      document2.attribute = 'Doc 2 attribute';

      final dynamic document3 = JsonObjectLite<dynamic>();
      document3.title = 'Document 3';
      document3.version = 3;
      document3.attribute = 'Doc 3 attribute';

      final docs = <String, JsonObjectLite<dynamic>>{};
      docs['docid1'] = document1;
      docs['docid2'] = document2;
      docs['docid3'] = document3;

      sporran5.bulkCreate(docs).then(wrapper);
    });

    test('3. Bulk Insert Documents Offline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.bulkCreatec);
        expect(res.id, isNull);
        expect(res.payload, isNotNull);
        expect(res.rev, isNull);
        final dynamic doc3 = res.payload['docid3offline'];
        expect(doc3.title, 'Document 3');
        expect(doc3.version, 3);
        expect(doc3.attribute, 'Doc 3 attribute');
      });

      final dynamic document1 = JsonObjectLite<dynamic>();
      document1.title = 'Document 1';
      document1.version = 1;
      document1.attribute = 'Doc 1 attribute';

      final dynamic document2 = JsonObjectLite<dynamic>();
      document2.title = 'Document 2';
      document2.version = 2;
      document2.attribute = 'Doc 2 attribute';

      final dynamic document3 = JsonObjectLite<dynamic>();
      document3.title = 'Document 3';
      document3.version = 3;
      document3.attribute = 'Doc 3 attribute';

      final docs = <String, JsonObjectLite<dynamic>>{};
      docs['docid1offline'] = document1;
      docs['docid2offline'] = document2;
      docs['docid3offline'] = document3;

      sporran5.online = false;
      sporran5.bulkCreate(docs).then(wrapper);
    });

    test('4. Get All Docs Online', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.getAllDocsc);
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        final dynamic successResponse = res.payload;
        expect(successResponse.total_rows, equals(3));
      });

      sporran5.online = true;
      sporran5.getAllDocs(includeDocs: true).then(wrapper);
    });

    test('5. Get All Docs Offline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.getAllDocsc);
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        expect(res.payload.length, greaterThanOrEqualTo(6));
        expect(res.payload['docid1'].payload.title, 'Document 1');
        expect(res.payload['docid2'].payload.title, 'Document 2');
        expect(res.payload['docid3'].payload.title, 'Document 3');
        expect(res.payload['docid1offline'].payload.title, 'Document 1');
        expect(res.payload['docid2offline'].payload.title, 'Document 2');
        expect(res.payload['docid3offline'].payload.title, 'Document 3');
      });

      sporran5.online = false;
      final keys = <String>[
        'docid1offline',
        'docid2offline',
        'docid3offline',
        'docid1',
        'docid2',
        'docid3'
      ];

      sporran5.getAllDocs(keys: keys).then(wrapper);
    });

    test('6. Get Database Info Offline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.dbInfoc);
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        expect(res.payload.length, greaterThanOrEqualTo(6));
        expect(res.payload.contains('docid1'), isTrue);
        expect(res.payload.contains('docid2'), isTrue);
        expect(res.payload.contains('docid3'), isTrue);
        expect(res.payload.contains('docid1offline'), isTrue);
        expect(res.payload.contains('docid2offline'), isTrue);
        expect(res.payload.contains('docid3offline'), isTrue);
      });

      sporran5.getDatabaseInfo().then(wrapper);
    });

    test('7. Get Database Info Online', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.dbInfoc);
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        expect(res.payload.doc_count, 3);
        expect(res.payload.db_name, databaseName);
      });

      sporran5.online = true;
      sporran5.getDatabaseInfo().then(wrapper);
    });

    test('8. Tidy Up All Docs Online', () {
      final dynamic wrapper = expectAsync1((dynamic res) {}, count: 3);

      sporran5.delete('docid1', docid1rev).then(wrapper);
      sporran5.delete('docid2', docid2rev).then(wrapper);
      sporran5.delete('docid3', docid3rev).then(wrapper);
    });
  });

  /* Group 6 - Sporran Change notification tests */
  group('6. Change notification Tests Documents - ', () {
    late Sporran sporran6;

    /* We use Wilt here to change the CouchDb database independently
     * of Sporran, these change will be picked up in change notifications.
     */

    /* Create our Wilt */
    final wilting = Wilt(hostName, port: port);

    /* Login if we are using authentication */
    wilting.login(userName, userPassword);

    wilting.db = databaseName;
    String? docId1Rev;
    String? docId2Rev;
    String? docId3Rev;

    test('1. Create and Open Sporran', () {
      final dynamic wrapper = expectAsync0(() {
        expect(sporran6.dbName, databaseName);
        expect(sporran6.lawnIsOpen, isTrue);
      });

      initialiser.manualNotificationControl = false;
      sporran6 = Sporran(initialiser);

      sporran6.autoSync = false;
      sporran6.onReady!.first.then((dynamic e) => wrapper());
    });

    test('2. Wilt - Bulk Insert Supplied Keys', () {
      final dynamic completer = expectAsync1((dynamic res) {
        try {
          expect(res.error, isFalse);
        } on Exception {
          logMessage('WILT::Bulk Insert Supplied Keys');
          final dynamic errorResponse = res.jsonCouchResponse;
          final String? errorText = errorResponse.error;
          logMessage('WILT::Error is $errorText');
          final String? reasonText = errorResponse.reason;
          logMessage('WILT::Reason is $reasonText');
          final int? statusCode = res.errorCode;
          logMessage('WILT::Status code is $statusCode');
          return;
        }

        final dynamic successResponse = res.jsonCouchResponse;
        expect(successResponse[0].id, equals('MyBulkId1'));
        expect(successResponse[1].id, equals('MyBulkId2'));
        expect(successResponse[2].id, equals('MyBulkId3'));
        docId1Rev = successResponse[0].rev;
        docId2Rev = successResponse[1].rev;
        docId3Rev = successResponse[2].rev;
      });

      final dynamic document1 = JsonObjectLite<dynamic>();
      document1.title = 'Document 1';
      document1.version = 1;
      document1.attribute = 'Doc 1 attribute';
      final doc1 = WiltUserUtils.addDocumentId(document1, 'MyBulkId1');
      final dynamic document2 = JsonObjectLite<dynamic>();
      document2.title = 'Document 2';
      document2.version = 2;
      document2.attribute = 'Doc 2 attribute';
      final doc2 = WiltUserUtils.addDocumentId(document2, 'MyBulkId2');
      final dynamic document3 = JsonObjectLite<dynamic>();
      document3.title = 'Document 3';
      document3.version = 3;
      document3.attribute = 'Doc 3 attribute';
      final doc3 = WiltUserUtils.addDocumentId(document3, 'MyBulkId3');
      final docList = <String>[];
      docList.add(doc1);
      docList.add(doc2);
      docList.add(doc3);
      final docs = WiltUserUtils.createBulkInsertString(docList);
      wilting.bulkString(docs).then(completer);
    });

    /* Pause a little for the notifications to come through */
    test('3. Notification Pause', () {
      final dynamic wrapper = expectAsync0(() {});
      Timer(const Duration(seconds: 3), wrapper);
    });

    /* Go offline and get our created documents, from local storage */
    test('4. Get Document Offline MyBulkId1', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isTrue);
        expect(res.id, 'MyBulkId1');
        expect(res.payload.title, 'Document 1');
        expect(res.payload.version, 1);
        expect(res.payload.attribute, 'Doc 1 attribute');
      });

      sporran6.online = false;
      sporran6.get('MyBulkId1').then(wrapper);
    });

    test('5. Get Document Offline MyBulkId2', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isTrue);
        expect(res.id, 'MyBulkId2');
        expect(res.payload.title, 'Document 2');
        expect(res.payload.version, 2);
        expect(res.payload.attribute, 'Doc 2 attribute');
      });

      sporran6.get('MyBulkId2').then(wrapper);
    });

    test('6. Get Document Offline MyBulkId3', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isTrue);
        expect(res.id, 'MyBulkId3');
        expect(res.payload.title, 'Document 3');
        expect(res.payload.version, 3);
        expect(res.payload.attribute, 'Doc 3 attribute');
      });

      sporran6.get('MyBulkId3').then(wrapper);
    });

    test('7. Wilt - Delete Document MyBulkId1', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        try {
          expect(res.error, isFalse);
        } on Exception {
          logMessage('WILT::Delete Document MyBulkId1');
          final dynamic errorResponse = res.jsonCouchResponse;
          final String? errorText = errorResponse.error;
          logMessage('WILT::Error is $errorText');
          final String? reasonText = errorResponse.reason;
          logMessage('WILT::Reason is $reasonText');
          final int? statusCode = res.errorCode;
          logMessage('WILT::Status code is $statusCode');
          return;
        }

        final dynamic successResponse = res.jsonCouchResponse;
        expect(successResponse.id, 'MyBulkId1');
      });

      wilting.deleteDocument('MyBulkId1', docId1Rev!).then(wrapper);
    });

    test('8. Wilt - Delete Document MyBulkId2', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        try {
          expect(res.error, isFalse);
        } on Exception {
          logMessage('WILT::Delete Document MyBulkId2');
          final dynamic errorResponse = res.jsonCouchResponse;
          final String? errorText = errorResponse.error;
          logMessage('WILT::Error is $errorText');
          final String? reasonText = errorResponse.reason;
          logMessage('WILT::Reason is $reasonText');
          final int? statusCode = res.errorCode;
          logMessage('WILT::Status code is $statusCode');
          return;
        }

        final dynamic successResponse = res.jsonCouchResponse;
        expect(successResponse.id, 'MyBulkId2');
      });

      wilting.deleteDocument('MyBulkId2', docId2Rev!).then(wrapper);
    });

    test('9. Wilt - Delete Document MyBulkId3', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        try {
          expect(res.error, isFalse);
        } on Exception {
          logMessage('WILT::Delete Document MyBulkId3');
          final dynamic errorResponse = res.jsonCouchResponse;
          final String? errorText = errorResponse.error;
          logMessage('WILT::Error is $errorText');
          final String? reasonText = errorResponse.reason;
          logMessage('WILT::Reason is $reasonText');
          final int? statusCode = res.errorCode;
          logMessage('WILT::Status code is $statusCode');
          return;
        }

        final dynamic successResponse = res.jsonCouchResponse;
        expect(successResponse.id, 'MyBulkId3');
      });

      wilting.deleteDocument('MyBulkId3', docId3Rev!).then(wrapper);
    });

    /* Pause a little for the notifications to come through */
    test('10. Notification Pause', () {
      final dynamic wrapper = expectAsync0(() {});
      Timer(const Duration(seconds: 3), wrapper);
    });

    /* Go offline and get our created documents, from local storage */
    test('11. Get Document Offline Deleted MyBulkId1', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isTrue);
      });

      sporran6.online = false;
      sporran6.get('MyBulkId1').then(wrapper);
    });

    test('12. Get Document Offline Deleted MyBulkId2', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isTrue);
      });

      sporran6.get('MyBulkId2').then(wrapper);
    });

    test('13. Get Document Offline Deleted MyBulkId3', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isTrue);
      });

      sporran6.get('MyBulkId3').then(wrapper);
    });

    test('14. Group Pause', () {
      final dynamic wrapper = expectAsync0(() {});
      Timer(const Duration(seconds: 3), wrapper);
    });
  }, skip: true);

  /* Group 7 - Sporran Change notification tests */
  group('7. Change notification Tests Attachments - ', () {
    late Sporran sporran7;

    /* We use Wilt here to change the CouchDb database independently
     * of Sporran, these change will be picked up in change notifications.
     */

    /* Create our Wilt */
    final wilting = Wilt(hostName, port: port);

    /* Login if we are using authentication */
    wilting.login(userName, userPassword);

    wilting.db = databaseName;
    String? docId1Rev;
    const attachmentPayload =
        'iVBORw0KGgoAAAANSUhEUgAAABwAAAASCAMAAAB/2U7WAAAABlBMVEUAAAD///+l2Z/dAAAASUlEQVR4XqWQUQoAIAxC2/0vXZDrEX4IJTRkb7lobNUStXsB0jIXIAMSsQnWlsV+wULF4Avk9fLq2r8a5HSE35Q3eO2XP1A1wQkZSgETvDtKdQAAAABJRU5ErkJggg==';

    test('1. Create and Open Sporran', () {
      final dynamic wrapper = expectAsync0(() {
        expect(sporran7.dbName, databaseName);
        expect(sporran7.lawnIsOpen, isTrue);
      });

      initialiser.manualNotificationControl = false;
      sporran7 = Sporran(initialiser);

      sporran7.autoSync = false;
      sporran7.onReady!.first.then((dynamic e) => wrapper());
    });

    test('2. Wilt - Bulk Insert Supplied Keys', () {
      final dynamic completer = expectAsync1((dynamic res) {
        try {
          expect(res.error, isFalse);
        } on Exception {
          logMessage('WILT::Bulk Insert Supplied Keys');
          final dynamic errorResponse = res.jsonCouchResponse;
          final String? errorText = errorResponse.error;
          logMessage('WILT::Error is $errorText');
          final String? reasonText = errorResponse.reason;
          logMessage('WILT::Reason is $reasonText');
          final int? statusCode = res.errorCode;
          logMessage('WILT::Status code is $statusCode');
          return;
        }

        final dynamic successResponse = res.jsonCouchResponse;
        expect(successResponse[0].id, equals('MyBulkId1'));
        expect(successResponse[1].id, equals('MyBulkId2'));
        expect(successResponse[2].id, equals('MyBulkId3'));
        docId1Rev = WiltUserUtils.getDocumentRev(successResponse[0]);
      });

      final dynamic document1 = JsonObjectLite<dynamic>();
      document1.title = 'Document 1';
      document1.version = 1;
      document1.attribute = 'Doc 1 attribute';
      final doc1 = WiltUserUtils.addDocumentId(document1, 'MyBulkId1');
      final dynamic document2 = JsonObjectLite<dynamic>();
      document2.title = 'Document 2';
      document2.version = 2;
      document2.attribute = 'Doc 2 attribute';
      final doc2 = WiltUserUtils.addDocumentId(document2, 'MyBulkId2');
      final dynamic document3 = JsonObjectLite<dynamic>();
      document3.title = 'Document 3';
      document3.version = 3;
      document3.attribute = 'Doc 3 attribute';
      final doc3 = WiltUserUtils.addDocumentId(document3, 'MyBulkId3');
      final docList = <String>[];
      docList.add(doc1);
      docList.add(doc2);
      docList.add(doc3);
      final docs = WiltUserUtils.createBulkInsertString(docList);
      wilting.bulkString(docs).then(completer);
    });

    /* Pause a little for the notifications to come through */
    test('3. Notification Pause', () {
      final dynamic wrapper = expectAsync0(() {});
      Timer(const Duration(seconds: 3), wrapper);
    });

    test('4. Create Attachment Online MyBulkId1 Attachment 1', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, 'MyBulkId1');
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        docId1Rev = res.rev;
        expect(res.payload.attachmentName, 'AttachmentName1');
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      sporran7.online = true;
      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName1';
      attachment.rev = docId1Rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran7.putAttachment('MyBulkId1', attachment).then(wrapper);
    });

    test('5. Create Attachment Online MyBulkId1 Attachment 2', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, 'MyBulkId1');
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        docId1Rev = res.rev;
        expect(res.payload.attachmentName, 'AttachmentName2');
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      sporran7.online = true;
      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName2';
      attachment.rev = docId1Rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran7.putAttachment('MyBulkId1', attachment).then(wrapper);
    });

    /* Pause a little for the notifications to come through */
    test('6. Notification Pause', () {
      final dynamic wrapper = expectAsync0(() {});
      Timer(const Duration(seconds: 3), wrapper);
    });

    test('7. Delete Attachment Online MyBulkId1 Attachment 1', () {
      final dynamic completer = expectAsync1((dynamic res) {
        try {
          expect(res.error, isFalse);
        } on Exception {
          logMessage('WILT::Delete Attachment Failed');
          final dynamic errorResponse = res.jsonCouchResponse;
          final String? errorText = errorResponse.error;
          logMessage('WILT::Error is $errorText');
          final String? reasonText = errorResponse.reason;
          logMessage('WILT::Reason is $reasonText');
          final int? statusCode = res.errorCode;
          logMessage('WILT::Status code is $statusCode');
          return;
        }

        final dynamic successResponse = res.jsonCouchResponse;
        expect(successResponse.ok, isTrue);
        docId1Rev = successResponse.rev;
      });

      wilting.db = databaseName;
      wilting
          .deleteAttachment('MyBulkId1', 'AttachmentName1', docId1Rev!)
          .then(completer);
    });

    test('8. Notification Pause', () {
      final dynamic wrapper = expectAsync0(() {});
      Timer(const Duration(seconds: 3), wrapper);
    });

    test('9. Get Attachment Offline MyBulkId1 AttachmentName1', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.getAttachmentc);
        expect(res.localResponse, isTrue);
      });

      sporran7.online = false;
      sporran7.getAttachment('MyBulkId1', 'AttachmentName1').then(wrapper);
    });
  });
}
