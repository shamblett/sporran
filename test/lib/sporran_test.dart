/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart';
import 'package:sporran/sporran.dart';
import 'package:json_object_lite/json_object_lite.dart';
import 'package:wilt/wilt.dart';
import 'package:test/test.dart';
import 'sporran_test_config.dart';

void logMessage(String message) {
  console.log(message.jsify());
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
    test('Online/Offline', () {
      var status = 'notset';

      EventHandler offline() {
        expect(status, 'offline');
        expect(window.navigator.onLine, isTrue);
        return null;
      }

      EventHandler online() {
        expect(status, 'online');
        expect(window.navigator.onLine, isTrue);
        return null;
      }

      status = 'offline';
      dynamic e = Event('offline');
      window.onoffline = (offline());
      window.dispatchEvent(e);
      status = 'online';
      e = Event('online');
      window.ononline = (online());
      window.dispatchEvent(e);
    });
  }, skip: false);

  // Group 2 - Sporran constructor/ invalid parameter tests
  group('2. Constructor/Invalid Parameter Tests - ', () {
    Sporran? sporran;

    test('0. Sporran Initialisation', () async {
      sporran = Sporran(initialiser)..initialise();
      sporran!.autoSync = false;
      await sporran!.onReady!.first;
      expect(sporran!.online, isTrue);
      expect(sporran, isNotNull);
      expect(sporran!.dbName, databaseName);
    });

    test('1. Construction Online/Offline listener ', () async {
      final sporran = Sporran(initialiser)..initialise();
      sporran.autoSync = false;
      await sporran.onReady!.first;
      final offline = Event('offline');
      window.dispatchEvent(offline);
      expect(sporran.online, isTrue);
      final online = Event('online');
      window.dispatchEvent(online);
    });

    test('2. Construction Existing Database ', () async {
      final sporran = Sporran(initialiser)..initialise();
      sporran.autoSync = false;
      await sporran.onReady!.first;
      expect(sporran, isNotNull);
      expect(sporran.dbName, databaseName);
    });

    test('3. Construction Invalid Authentication ', () async {
      initialiser.password = 'none';
      Sporran? sporran = Sporran(initialiser)..initialise();
      initialiser.password = userPassword;
      sporran.autoSync = false;
      await sporran.onReady!.first;
      expect(sporran, isNotNull);
      expect(sporran.dbName, databaseName);
    });

    test('4. Put No Doc Id ', () async {
      final res = await sporran!.put('', JsonObjectLite<dynamic>());
      expect(res, isNull);
    });

    test('5. Get No Doc Id ', () async {
      final res = await sporran!.get('', '');
      expect(res, isNull);
    });

    test('6. Delete No Doc Id ', () async {
      final res = await sporran!.delete('', '');
      expect(res, isNull);
    });

    test('7. Put Attachment No Doc Id ', () async {
      final res = await sporran!.putAttachment('', null);
      expect(res, isNull);
    });

    test('8. Put Attachment No Attachment ', () async {
      final res = await sporran!.putAttachment('billy', null);
      expect(res, isNull);
    });

    test('9. Delete Attachment No Doc Id ', () async {
      final res = await sporran!.deleteAttachment('', '', '');
      expect(res, isNull);
    });

    test('10. Delete Attachment No Attachment Name ', () async {
      final res = await sporran!.deleteAttachment('billy', '', '');
      expect(res, isNull);
    });

    test('12. Get Attachment No Doc Id ', () async {
      final res = await sporran!.getAttachment('', '');
      expect(res, isNull);
    });

    test('13. Get Attachment No Attachment Name ', () async {
      final res = await sporran!.getAttachment('billy', '');
      expect(res, isNull);
    });

    test('14. Bulk Create No Document List ', () async {
      final res =
          await sporran!.bulkCreate(<String, JsonObjectLite<dynamic>>{});
      expect(res, isNull);
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

  // Group 3 - Sporran document put/get tests
  group('3. Document Put/Get/Delete Tests - ', () {
    late Sporran sporran3;

    const docIdPutOnline = 'putOnlineg3';
    const docIdPutOffline = 'putOfflineg3';
    final dynamic onlineDoc = JsonObjectLite<dynamic>();
    final dynamic offlineDoc = JsonObjectLite<dynamic>();
    var onlineDocRev = '';

    test('1. Create and Open Sporran', () async {
      sporran3 = Sporran(initialiser)..initialise();
      sporran3.autoSync = false;
      await sporran3.onReady!.first;
      expect(sporran3.dbName, databaseName);
      expect(sporran3.lawnIsOpen, isTrue);
    });

    test('2. Put Document Online docIdPutOnline', () async {
      sporran3.online = true;
      onlineDoc.name = 'Online';
      final res = await sporran3.put(docIdPutOnline, onlineDoc);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.putc);
      expect(res.localResponse, isFalse);
      expect(res.id, docIdPutOnline);
      expect(res.rev, anything);
      onlineDocRev = res.rev;
      final payload = JsonObjectLite();
      JsonObjectLite.toTypedJsonObjectLite(res.payload, payload);
      expect(payload['name'], 'Online');
    });

    test('3. Put Document Offline docIdPutOffline', () async {
      sporran3.online = false;
      offlineDoc.name = 'Offline';
      final res = await sporran3.put(docIdPutOffline, offlineDoc);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.putc);
      expect(res.localResponse, isTrue);
      expect(res.id, docIdPutOffline);
      expect(res.payload.name, 'Offline');
    });

    test('4. Put Document Online Conflict', () async {
      sporran3.online = true;
      onlineDoc.name = 'Online';
      final res = await sporran3.put(docIdPutOnline, onlineDoc);
      expect(res.errorCode, 409);
      expect(res.jsonCouchResponse.error, 'conflict');
      expect(res.operation, Sporran.putc);
      expect(res.id, docIdPutOnline);
    });

    test('5. Put Document Online Updated docIdPutOnline', () async {
      onlineDoc.name = 'Online - Updated';
      final res = await sporran3.put(docIdPutOnline, onlineDoc, onlineDocRev);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.putc);
      expect(res.localResponse, isFalse);
      expect(res.id, docIdPutOnline);
      expect(res.rev, anything);
      expect(res.payload.name, 'Online - Updated');
    });

    test('6. Get Document Offline docIdPutOnline', () async {
      sporran3.online = false;
      final res = await sporran3.get(docIdPutOnline);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.getc);
      expect(res.localResponse, isTrue);
      expect(res.id, docIdPutOnline);
      final dynamic payload =
          JsonObjectLite<dynamic>.fromJsonString(res.payload);
      expect(payload.payload.name, 'Online - Updated');
    });

    test('7. Get Document Offline docIdPutOffline', () async {
      sporran3.online = false;
      final res = await sporran3.get(docIdPutOffline);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.getc);
      expect(res.localResponse, isTrue);
      expect(res.id, docIdPutOffline);
      final dynamic payload =
          JsonObjectLite<dynamic>.fromJsonString(res.payload);
      expect(payload.payload.name, 'Offline');
      expect(res.rev, isNull);
    });

    test('8. Get Document Offline Not Exist', () async {
      sporran3.online = false;
      offlineDoc.name = 'Offline';
      final res = await sporran3.get('Billy');
      expect(res.ok, isFalse);
      expect(res.operation, Sporran.getc);
      expect(res.localResponse, isTrue);
      expect(res.id, 'Billy');
      expect(res.rev, isNull);
      expect(res.payload, isNull);
    });

    test('9. Get Document Online docIdPutOnline', () async {
      sporran3.online = true;
      final res = await sporran3.get(docIdPutOnline);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.getc);
      expect(res.payload.name, 'Online - Updated');
      expect(res.localResponse, isFalse);
      expect(res.id, docIdPutOnline);
      onlineDocRev = res.rev;
    });

    test('10. Delete Document Offline', () async {
      sporran3.online = false;
      final res = await sporran3.delete(docIdPutOffline);
      expect(res.ok, isTrue);
      expect(res.localResponse, isTrue);
      expect(res.operation, Sporran.deletec);
      expect(res.id, docIdPutOffline);
      expect(res.payload, isNull);
      expect(res.rev, '');
      expect(sporran3.pendingDeleteSize, 1);
    });

    test('11. Delete Document Online', () async {
      sporran3.online = true;
      final res = await sporran3.delete(docIdPutOnline, onlineDocRev);
      expect(res.ok, isTrue);
      expect(res.localResponse, isFalse);
      expect(res.operation, Sporran.deletec);
      expect(res.id, docIdPutOnline);
      expect(res.payload, isNotNull);
      expect(res.rev, anything);
    });

    test('12. Get Document Online Not Exist', () async {
      final res = await sporran3.get('Billy');
      expect(res.ok, isFalse);
      expect(res.operation, Sporran.getc);
      expect(res.localResponse, isFalse);
      expect(res.id, 'Billy');
    });

    test('13. Delete Document Not Exist', () async {
      sporran3.online = false;
      final res = await sporran3.delete('Billy');
      expect(res.ok, isFalse);
      expect(res.operation, Sporran.deletec);
      expect(res.id, 'Billy');
      expect(res.payload, isNull);
      expect(res.rev, isNull);
    });
  }, skip: false);

  // Group 4 - Sporran attachment put/get tests
  group('4. Attachment Put/Get/Delete Tests - ', () {
    late Sporran sporran4;

    const docIdPutOnline = 'putOnlineg4';
    const docIdPutOffline = 'putOfflineg4';
    final dynamic onlineDoc = JsonObjectLite<dynamic>();
    final dynamic offlineDoc = JsonObjectLite<dynamic>();
    var onlineDocRev = '';

    const attachmentPayload =
        'iVBORw0KGgoAAAANSUhEUgAAABwAAAASCAMAAAB/2U7WAAAABlBMVEUAAAD///+l2Z/dAAAASUlEQVR4XqWQUQoAIAxC2/0vXZDrEX4IJTRkb7lobNUStXsB0jIXIAMSsQnWlsV+wULF4Avk9fLq2r8a5HSE35Q3eO2XP1A1wQkZSgETvDtKdQAAAABJRU5ErkJggg==';

    test('1. Create and Open Sporran', () async {
      sporran4 = Sporran(initialiser)..initialise();
      sporran4.autoSync = false;
      await sporran4.onReady!.first;
      expect(sporran4.dbName, databaseName);
      expect(sporran4.lawnIsOpen, isTrue);
    });

    test('2. Put Document Online docIdPutOnline', () async {
      sporran4.online = true;
      onlineDoc.name = 'Online';
      final res = await sporran4.put(docIdPutOnline, onlineDoc);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.putc);
      expect(res.id, docIdPutOnline);
      expect(res.localResponse, isFalse);
      expect(res.payload.name, 'Online');
      expect(res.rev, anything);
      onlineDocRev = res.rev;
    });

    test('3. Put Document Offline docIdPutOffline', () async {
      sporran4.online = false;
      offlineDoc.name = 'Offline';
      final res = await sporran4.put(docIdPutOffline, offlineDoc);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.putc);
      expect(res.id, docIdPutOffline);
      expect(res.localResponse, isTrue);
      expect(res.payload.name, 'Offline');
    });

    test('4. Create Attachment Online docIdPutOnline', () async {
      sporran4.online = true;
      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'onlineAttachment';
      attachment.rev = onlineDocRev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      final res = await sporran4.putAttachment(docIdPutOnline, attachment);
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

    test('5. Create Attachment Offline docIdPutOffline', () async {
      sporran4.online = false;
      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'offlineAttachment';
      attachment.rev = onlineDocRev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      final res = await sporran4.putAttachment(docIdPutOffline, attachment);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.putAttachmentc);
      expect(res.id, docIdPutOffline);
      expect(res.localResponse, isTrue);
      expect(res.rev, isNull);
      expect(res.payload.attachmentName, 'offlineAttachment');
      expect(res.payload.contentType, 'image/png');
      expect(res.payload.payload, attachmentPayload);
    });

    test('6. Get Attachment Online docIdPutOnline', () async {
      sporran4.online = true;
      final res =
          await sporran4.getAttachment(docIdPutOnline, 'onlineAttachment');
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.getAttachmentc);
      expect(res.id, docIdPutOnline);
      expect(res.localResponse, isFalse);
      expect(res.rev, anything);
      expect(res.payload.attachmentName, 'onlineAttachment');
      expect(res.payload.contentType, 'image/png; charset=utf-8');
      expect(res.payload.payload, attachmentPayload);
    });

    test('7. Get Attachment Offline docIdPutOffline', () async {
      sporran4.online = false;
      final res =
          await sporran4.getAttachment(docIdPutOffline, 'offlineAttachment');
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

    test('8. Get Document Online docIdPutOnline', () async {
      sporran4.online = true;
      final res = await sporran4.get(docIdPutOnline, onlineDocRev);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.getc);
      expect(res.id, docIdPutOnline);
      expect(res.localResponse, isFalse);
      expect(res.rev, onlineDocRev);
      final attachments = WiltUserUtils.getAttachments(res.payload);
      expect(attachments.length, 1);
    });

    test('9. Delete Attachment Online docIdPutOnline', () async {
      sporran4.online = true;
      final res = await sporran4.deleteAttachment(
          docIdPutOnline, 'onlineAttachment', onlineDocRev);
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.deleteAttachmentc);
      expect(res.id, docIdPutOnline);
      expect(res.localResponse, isFalse);
      onlineDocRev = res.rev;
      expect(res.rev, anything);
    });

    test('10. Delete Document Online docIdPutOnline', () async {
      /* Tidy up only, tested in group 3 */
      await sporran4.delete(docIdPutOnline, onlineDocRev);
    });

    test('11. Delete Attachment Offline docIdPutOffline', () async {
      sporran4.online = false;
      final res = await sporran4.deleteAttachment(
          docIdPutOffline, 'offlineAttachment', '');
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.deleteAttachmentc);
      expect(res.id, docIdPutOffline);
      expect(res.localResponse, isTrue);
      expect(res.rev, isNull);
      expect(res.payload, isNull);
    });

    test('12. Delete Attachment Not Exist', () async {
      sporran4.online = false;
      final res = await sporran4.deleteAttachment(docIdPutOffline, 'Billy', '');
      expect(res.ok, isFalse);
      expect(res.operation, Sporran.deleteAttachmentc);
      expect(res.id, docIdPutOffline);
      expect(res.localResponse, isTrue);
      expect(res.rev, isNull);
      expect(res.payload, isNull);
    }, skip: false);
  });

  // Group 5 - Sporran Bulk Documents tests
  group('5. Bulk Document Tests - ', () {
    late Sporran sporran5;
    var docid1rev = '';
    var docid2rev = '';
    var docid3rev = '';

    test('1. Create and Open Sporran', () async {
      sporran5 = Sporran(initialiser)..initialise();
      sporran5.autoSync = false;
      await sporran5.onReady!.first;
      expect(sporran5.dbName, databaseName);
      expect(sporran5.lawnIsOpen, isTrue);
    });

    test('2. Bulk Insert Documents Online', () async {
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

      final res = await sporran5.bulkCreate(docs);
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
      expect(doc3['title'], 'Document 3');
      expect(doc3['version'], 3);
      expect(doc3['attribute'], 'Doc 3 attribute');
    });

    test('3. Bulk Insert Documents Offline', () async {
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
      final res = await sporran5.bulkCreate(docs);
      expect(res.ok, isTrue);
      expect(res.localResponse, isTrue);
      expect(res.operation, Sporran.bulkCreatec);
      expect(res.id, isNull);
      expect(res.payload, isNotNull);
      expect(res.rev, isNull);
      final dynamic doc3 = res.payload['docid3offline'];
      expect(doc3['title'], 'Document 3');
      expect(doc3['version'], 3);
      expect(doc3['attribute'], 'Doc 3 attribute');
    });

    test('4. Get All Docs Online', () async {
      sporran5.online = true;
      final dynamic res = await sporran5.getAllDocs(includeDocs: true);
      expect(res.ok, isTrue);
      expect(res.localResponse, isFalse);
      expect(res.operation, Sporran.getAllDocsc);
      expect(res.id, isNull);
      expect(res.rev, isNull);
      expect(res.payload, isNotNull);
      final successResponse = JsonObjectLite();
      JsonObjectLite.toTypedJsonObjectLite(res.payload, successResponse);
      expect(successResponse['total_rows'], equals(5));
    });

    test('5. Get All Docs Offline', () async {
      sporran5.online = false;
      final keys = <String>[
        'docid1offline',
        'docid2offline',
        'docid3offline',
        'docid1',
        'docid2',
        'docid3'
      ];

      final dynamic res = await sporran5.getAllDocs(keys: keys);
      expect(res.ok, isTrue);
      expect(res.localResponse, isTrue);
      expect(res.operation, Sporran.getAllDocsc);
      expect(res.id, isNull);
      expect(res.rev, isNull);
      expect(res.payload, isNotNull);
      expect(res.payload.length, greaterThanOrEqualTo(6));
      expect(res.payload['docid1'].payload['title'], 'Document 1');
      expect(res.payload['docid2'].payload['title'], 'Document 2');
      expect(res.payload['docid3'].payload['title'], 'Document 3');
      expect(res.payload['docid1offline'].payload['title'], 'Document 1');
      expect(res.payload['docid2offline'].payload['title'], 'Document 2');
      expect(res.payload['docid3offline'].payload['title'], 'Document 3');
    });

    test('6. Get Database Info Offline', () async {
      final dynamic res = await sporran5.getDatabaseInfo();
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

    test('7. Get Database Info Online', () async {
      sporran5.online = true;
      final dynamic res = await sporran5.getDatabaseInfo();
      expect(res.ok, isTrue);
      expect(res.localResponse, isFalse);
      expect(res.operation, Sporran.dbInfoc);
      expect(res.id, isNull);
      expect(res.rev, isNull);
      expect(res.payload, isNotNull);
      expect(res.payload['doc_count'], lessThanOrEqualTo(8));
      expect(res.payload['db_name'], databaseName);
    });

    test('8. Tidy Up All Docs Online', () async {
      await sporran5.delete('docid1', docid1rev);
      await sporran5.delete('docid2', docid2rev);
      await sporran5.delete('docid3', docid3rev);
    });
  });

  // Group 6 - Sporran Change notification tests
  group('6. Change notification Tests Documents - ', () {
    late Sporran sporran6;

    // We use Wilt here to change the CouchDb database independently
    // of Sporran, these change will be picked up in change notifications.

    // Create our Wilt
    final wilting = Wilt(hostName, port: port);

    // Login if we are using authentication
    wilting.login(userName, userPassword);

    wilting.db = databaseName;
    String? docId1Rev;
    String? docId2Rev;
    String? docId3Rev;

    test('1. Create and Open Sporran', () async {
      initialiser.manualNotificationControl = false;
      sporran6 = Sporran(initialiser)..initialise();
      sporran6.autoSync = false;
      await sporran6.onReady!.first;
      expect(sporran6.dbName, databaseName);
      expect(sporran6.lawnIsOpen, isTrue);
    });

    test('2. Wilt - Bulk Insert Supplied Keys', () async {
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
      final res = await wilting.bulkString(docs);
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

    // Pause a little for the notifications to come through //
    test('3. Notification Pause', () async {
      await Future.delayed(Duration(seconds: 3));
    });

    // Go offline and get our created documents, from local storage
    test('4. Get Document Offline MyBulkId1', () async {
      sporran6.online = false;
      final res = await sporran6.get('MyBulkId1');
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.getc);
      expect(res.localResponse, isTrue);
      expect(res.id, 'MyBulkId1');
      expect(res.payload['title'], 'Document 1');
      expect(res.payload['version'], 1);
      expect(res.payload['attribute'], 'Doc 1 attribute');
    });

    test('5. Get Document Offline MyBulkId2', () async {
      final res = await sporran6.get('MyBulkId2');
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.getc);
      expect(res.localResponse, isTrue);
      expect(res.id, 'MyBulkId2');
      expect(res.payload['title'], 'Document 2');
      expect(res.payload['version'], 2);
      expect(res.payload['attribute'], 'Doc 2 attribute');
    });

    test('6. Get Document Offline MyBulkId3', () async {
      final res = await sporran6.get('MyBulkId3');
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.getc);
      expect(res.localResponse, isTrue);
      expect(res.id, 'MyBulkId3');
      expect(res.payload['title'], 'Document 3');
      expect(res.payload['version'], 3);
      expect(res.payload['attribute'], 'Doc 3 attribute');
    });

    test('7. Wilt - Delete Document MyBulkId1', () async {
      final res = await wilting.deleteDocument('MyBulkId1', docId1Rev!);
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

    test('8. Wilt - Delete Document MyBulkId2', () async {
      final res = await wilting.deleteDocument('MyBulkId2', docId2Rev!);
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

    test('9. Wilt - Delete Document MyBulkId3', () async {
      final res = await wilting.deleteDocument('MyBulkId3', docId3Rev!);
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

    /* Pause a little for the notifications to come through */
    test('10. Notification Pause', () async {
      await Future.delayed(Duration(seconds: 3));
    });

    // Go offline and get our created documents, from local storage
    test('11. Get Document Offline Deleted MyBulkId1', () async {
      sporran6.online = false;
      final res = await sporran6.get('MyBulkId1');
      expect(res.ok, isFalse);
      expect(res.operation, Sporran.getc);
      expect(res.localResponse, isTrue);
    });

    test('12. Get Document Offline Deleted MyBulkId2', () async {
      final res = await sporran6.get('MyBulkId2');
      expect(res.ok, isFalse);
      expect(res.operation, Sporran.getc);
      expect(res.localResponse, isTrue);
    });

    test('13. Get Document Offline Deleted MyBulkId3', () async {
      final res = await sporran6.get('MyBulkId3');
      expect(res.ok, isFalse);
      expect(res.operation, Sporran.getc);
      expect(res.localResponse, isTrue);
    });

    test('14. Group Pause', () async {
      await Future.delayed(Duration(seconds: 3));
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
      sporran7 = Sporran(initialiser)..initialise();

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
