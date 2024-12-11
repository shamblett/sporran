/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */
@TestOn('browser')
library;

import 'package:sporran/sporran.dart';
import 'package:json_object_lite/json_object_lite.dart';
import 'package:wilt/wilt.dart';
import 'package:test/test.dart';
import 'sporran_test_config.dart';

void main() async {
  /* Common initialiser */
  final initialiser = SporranInitialiser();
  initialiser.dbName = 'sporranscenariotest3';
  initialiser.hostname = hostName;
  initialiser.manualNotificationControl = false;
  initialiser.port = port;
  initialiser.scheme = scheme;
  initialiser.username = userName;
  initialiser.password = userPassword;
  initialiser.preserveLocal = false;

  // Delete any existing test databases
  final deleter = Wilt(hostName);
  deleter.login(userName, userPassword);
  await deleter.deleteDatabase('scenariotest2');

  /* Group 9 - Sporran Scenario test 3 */
  /**
   *  Start offline
   *  Bulk create 3 docs
   *  Add two attachments
   *  Delete one document
   *  Kill sporran
   *  Construct a sporran
   *  Check the documents above still exist
   */

  group('9. Scenario Tests 1 - ', () {
    Sporran? sporran9;
    late Sporran sporran10;
    var docid1rev = '';
    var docid2rev = '';
    var docid3rev = '';
    const attachmentPayload =
        'iVBORw0KGgoAAAANSUhEUgAAABwAAAASCAMAAAB/2U7WAAAABlBMVEUAAAD///+l2Z/dAAAASUlEQVR4XqWQUQoAIAxC2/0vXZDrEX4IJTRkb7lobNUStXsB0jIXIAMSsQnWlsV+wULF4Avk9fLq2r8a5HSE35Q3eO2XP1A1wQkZSgETvDtKdQAAAABJRU5ErkJggg==';

    test('1. Create and Open Sporran', () {
      final dynamic wrapper = expectAsync0(() {
        expect(sporran9!.dbName, 'sporranscenariotest3');
        expect(sporran9!.lawnIsOpen, isTrue);
        sporran9!.online = false;
      });

      sporran9 = Sporran(initialiser)..initialise();
      sporran9!.onReady!.first.then((dynamic e) => wrapper());
    });

    test('2. Bulk Insert Documents Offline', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.bulkCreatec);
        expect(res.id, isNull);
        expect(res.payload, isNotNull);
        expect(res.rev, isNull);
        final dynamic doc3 = res.payload['8docid3'];
        expect(doc3['title'], 'Document 3');
        expect(doc3['version'], 3);
        expect(doc3['attribute'], 'Doc 3 attribute');
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
      docs['8docid1'] = document1;
      docs['8docid2'] = document2;
      docs['8docid3'] = document3;

      sporran9!.bulkCreate(docs).then(wrapper);
    });

    test('3. Create Attachment Offline docid1 Attachment 1', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, '8docid1');
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        expect(res.payload['attachmentName'], 'AttachmentName1');
        expect(res.payload['contentType'], 'image/png');
        expect(res.payload['payload'], attachmentPayload);
      });

      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName1';
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9!.putAttachment('8docid1', attachment).then(wrapper);
    });

    test('4. Create Attachment Offline docid1 Attachment 2', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, '8docid1');
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        expect(res.payload['attachmentName'], 'AttachmentName2');
        expect(res.payload['contentType'], 'image/png');
        expect(res.payload['payload'], attachmentPayload);
      });

      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName2';
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9!.putAttachment('8docid1', attachment).then(wrapper);
    });

    test('5. Create Attachment Offline docid2 Attachment 1', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, '8docid2');
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        expect(res.payload['attachmentName'], 'AttachmentName1');
        expect(res.payload['contentType'], 'image/png');
        expect(res.payload['payload'], attachmentPayload);
      });

      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName1';
      attachment.rev = docid2rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9!.putAttachment('8docid2', attachment).then(wrapper);
    });

    test('6. Delete Document Offline docid3', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.deletec);
        expect(res.id, '8docid3');
        expect(res.payload, isNull);
        expect(res.rev, '');
        expect(sporran9!.pendingDeleteSize, 1);
      });

      sporran9!.delete('8docid3', docid3rev).then(wrapper);
    });

    test('7. Check - Get All Docs Offline - Existing Sporran', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.getAllDocsc);
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        expect(res.totalRows, equals(2));
        final List<String> keyList = res.keyList;
        expect(keyList[0], '8docid1');
        expect(keyList[1], '8docid2');
        expect(res.payload[keyList[0]].key, equals('8docid1'));
        expect(res.payload[keyList[0]].payload['title'], 'Document 1');
        expect(res.payload[keyList[0]].payload['version'], 1);
        expect(res.payload[keyList[0]].payload['attribute'], 'Doc 1 attribute');
        expect(res.payload[keyList[1]].key, equals('8docid2'));
        expect(res.payload[keyList[1]].payload['title'], 'Document 2');
        expect(res.payload[keyList[1]].payload['version'], 2);
        expect(res.payload[keyList[1]].payload['attribute'], 'Doc 2 attribute');
        /* Kill this sporran */
        sporran9 = null;
      });
      final keys = const <String>[];
      sporran9!.getAllDocs(includeDocs: true, keys: keys).then(wrapper);
    });

    test('8. Check - Get All Docs Offline -  Sporran', () {
      final dynamic wrapper1 = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.getAllDocsc);
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        expect(res.totalRows, equals(2));
        final List<String> keyList = res.keyList;
        expect(keyList[0], '8docid1');
        expect(keyList[1], '8docid2');
        expect(res.payload[keyList[0]].key, equals('8docid1'));
        expect(res.payload[keyList[0]].payload['title'], 'Document 1');
        expect(res.payload[keyList[0]].payload['version'], 1);
        expect(res.payload[keyList[0]].payload['attribute'], 'Doc 1 attribute');
        expect(res.payload[keyList[1]].key, equals('8docid2'));
        expect(res.payload[keyList[1]].payload['title'], 'Document 2');
        expect(res.payload[keyList[1]].payload['version'], 2);
        expect(res.payload[keyList[1]].payload['attribute'], 'Doc 2 attribute');
      });

      final dynamic wrapper = expectAsync0(() {
        expect(sporran10.dbName, 'sporranscenariotest3');
        expect(sporran10.lawnIsOpen, isTrue);
        sporran10.online = false;

        final keys = const <String>[];
        sporran10.getAllDocs(includeDocs: true, keys: keys).then(wrapper1);
      });

      initialiser.preserveLocal = true;
      sporran10 = Sporran(initialiser)..initialise();
      sporran10.onReady!.first.then((dynamic e) => wrapper());
    });
  });
}
