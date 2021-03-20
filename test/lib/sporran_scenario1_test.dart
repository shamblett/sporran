/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */

@TestOn('browser')

import 'dart:async';
import 'package:wilt/wilt.dart';
import 'package:sporran/sporran.dart';
import 'package:json_object_lite/json_object_lite.dart';
import 'package:test/test.dart';
import 'sporran_test_config.dart';

void main() async {
  /* Common initialiser */
  final initialiser = SporranInitialiser();
  initialiser.dbName = 'scenariotest1';
  initialiser.hostname = hostName;
  initialiser.manualNotificationControl = false;
  initialiser.port = port;
  initialiser.scheme = scheme;
  initialiser.username = userName;
  initialiser.password = userPassword;
  initialiser.preserveLocal = false;

  // Delete any existing test databases
  final deleter = Wilt('localhost');
  deleter.login(userName, userPassword);
  await deleter.deleteDatabase('scenariotest1');

  /* Group 8 - Sporran Scenario test 1 */
  /**
   *  Start offline
   *  Bulk create 3 docs
   *  Add two attachments
   *  Delete one document
   *  Go online
   *  Check that sync worked.
   *
   */

  group('8. Scenario Tests 1 - ', () {
    late Sporran sporran8;
    var docid1rev = '';
    var docid2rev = '';
    var docid3rev = '';
    const attachmentPayload =
        'iVBORw0KGgoAAAANSUhEUgAAABwAAAASCAMAAAB/2U7WAAAABlBMVEUAAAD///+l2Z/dAAAASUlEQVR4XqWQUQoAIAxC2/0vXZDrEX4IJTRkb7lobNUStXsB0jIXIAMSsQnWlsV+wULF4Avk9fLq2r8a5HSE35Q3eO2XP1A1wQkZSgETvDtKdQAAAABJRU5ErkJggg==';

    test('1. Create and Open Sporran', () {
      final dynamic wrapper = expectAsync0(() {
        expect(sporran8.dbName, 'scenariotest1');
        expect(sporran8.lawnIsOpen, isTrue);
        sporran8.online = false;
      });

      sporran8 = Sporran(initialiser);
      sporran8.onReady!.first.then((dynamic e) => wrapper());
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
      docs['8docid1'] = document1;
      docs['8docid2'] = document2;
      docs['8docid3'] = document3;

      sporran8.bulkCreate(docs).then(wrapper);
    });

    test('3. Create Attachment Offline docid1 Attachment 1', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, '8docid1');
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        docid1rev = res.rev ?? '';
        expect(res.payload.attachmentName, 'AttachmentName1');
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName1';
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran8.putAttachment('8docid1', attachment).then(wrapper);
    });

    test('4. Create Attachment Offline docid1 Attachment 2', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, '8docid1');
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        docid1rev = res.rev ?? '';
        expect(res.payload.attachmentName, 'AttachmentName2');
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName2';
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran8.putAttachment('8docid1', attachment).then(wrapper);
    });

    test('5. Create Attachment Offline docid2 Attachment 1', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, '8docid2');
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        docid2rev = res.rev ?? '';
        expect(res.payload.attachmentName, 'AttachmentName1');
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName1';
      attachment.rev = docid2rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran8.putAttachment('8docid2', attachment).then(wrapper);
    });

    test('6. Delete Document Offline docid3', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.deletec);
        expect(res.id, '8docid3');
        expect(res.payload, isNull);
        expect(res.rev, isNull);
        expect(sporran8.pendingDeleteSize, 1);
      });

      sporran8.delete('8docid3', docid3rev).then(wrapper);
    });

    test('7. Check - Get All Docs Online', () {
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.getAllDocsc);
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        final dynamic successResponse = res.payload;
        expect(successResponse.total_rows, equals(2));
        expect(successResponse.rows[0].id, equals('8docid1'));
        var tmp = WiltUserUtils.getDocumentRev(successResponse.rows[0].doc);
        if (tmp != null) {
          docid1rev = tmp;
        }
        expect(successResponse.rows[1].id, equals('8docid2'));
        tmp = WiltUserUtils.getDocumentRev(successResponse.rows[1].doc);
        if (tmp != null) {
          docid2rev = tmp;
        }
        expect(successResponse.rows[0].doc.title, 'Document 1');
        expect(successResponse.rows[0].doc.version, 1);
        expect(successResponse.rows[0].doc.attribute, 'Doc 1 attribute');
        final doc1Attachments =
            WiltUserUtils.getAttachments(successResponse.rows[0].doc);
        expect(doc1Attachments.length, 2);
        expect(successResponse.rows[1].doc.title, 'Document 2');
        expect(successResponse.rows[1].doc.version, 2);
        expect(successResponse.rows[1].doc.attribute, 'Doc 2 attribute');
        final doc2Attachments =
            WiltUserUtils.getAttachments(successResponse.rows[1].doc);
        expect(doc2Attachments.length, 1);
      });

      final dynamic cmdWrapper = expectAsync0(() {
        sporran8.getAllDocs(includeDocs: true).then(wrapper);
      });
      sporran8.online = true;
      Timer(const Duration(seconds: 20), cmdWrapper);
    });
  });
}
