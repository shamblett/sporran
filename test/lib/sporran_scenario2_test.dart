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

void main() {
  /* Group 8 - Sporran Scenario test 2 */
  /**
   *  Start online
   *  Bulk create 3 docs
   *  Add two attachments
   *  Go offline
   *  Delete one document
   *  Delete one attachment
   *  Update 1 document
   *  Add 1 document
   *  Go online
   *  Check that sync worked.
   *
   */

  group('9. Scenario Tests 2 - ', () {
    late Sporran sporran9;
    String? docid1rev;
    String? docid2rev;
    String? docid3rev;
    const attachmentPayload =
        'iVBORw0KGgoAAAANSUhEUgAAABwAAAASCAMAAAB/2U7WAAAABlBMVEUAAAD///+l2Z/dAAAASUlEQVR4XqWQUQoAIAxC2/0vXZDrEX4IJTRkb7lobNUStXsB0jIXIAMSsQnWlsV+wULF4Avk9fLq2r8a5HSE35Q3eO2XP1A1wQkZSgETvDtKdQAAAABJRU5ErkJggg==';

    /* Common initialiser */
    final initialiser = SporranInitialiser();
    initialiser.dbName = databaseName;
    initialiser.hostname = hostName;
    initialiser.manualNotificationControl = false;
    initialiser.port = port;
    initialiser.scheme = scheme;
    initialiser.username = userName;
    initialiser.password = userPassword;
    initialiser.preserveLocal = false;
    Timer? pause;
    print(pause);

    test('1. Create and Open Sporran', () {
      print('9.1');
      final dynamic wrapper = expectAsync0(() {
        expect(sporran9.dbName, databaseName);
        expect(sporran9.lawnIsOpen, isTrue);
      });

      sporran9 = Sporran(initialiser);
      sporran9.onReady!.first.then((dynamic e) => wrapper());
    });

    test('2. Bulk Insert Documents Online', () {
      print('9.2');
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.bulkCreatec);
        expect(res.id, isNull);
        expect(res.payload, isNotNull);
        expect(res.rev, isNotNull);
        expect(res.rev[0], isNotNull);
        docid1rev = res.rev[0].rev;
        expect(docid1rev, anything);
        expect(res.rev[1], isNotNull);
        docid2rev = res.rev[1].rev;
        expect(docid1rev, anything);
        expect(res.rev[2], isNotNull);
        docid3rev = res.rev[2].rev;
        expect(docid1rev, anything);
        final dynamic doc3 = res.payload['9docid3'];
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
      docs['9docid1'] = document1;
      docs['9docid2'] = document2;
      docs['9docid3'] = document3;

      sporran9.bulkCreate(docs).then(wrapper);
    });

    test('3. Create Attachment Online docid1 Attachment 1', () {
      print('9.3');
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, '9docid1');
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        docid1rev = res.rev;
        expect(res.payload.attachmentName, 'AttachmentName1');
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName1';
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9.putAttachment('9docid1', attachment).then(wrapper);
    });

    test('4. Create Attachment Online docid1 Attachment 2', () {
      print('9.4');
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, '9docid1');
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        docid1rev = res.rev;
        expect(res.payload.attachmentName, 'AttachmentName2');
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName2';
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9.putAttachment('9docid1', attachment).then(wrapper);
    });

    test('5. Create Attachment Online docid2 Attachment 1', () {
      print('9.5');
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, '9docid2');
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        docid2rev = res.rev;
        expect(res.payload.attachmentName, 'AttachmentName1');
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      final dynamic attachment = JsonObjectLite<dynamic>();
      attachment.attachmentName = 'AttachmentName1';
      attachment.rev = docid2rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9.putAttachment('9docid2', attachment).then(wrapper);
    });

    test('6. Sync Pause', () {
      print('9.6');
      final dynamic wrapper = expectAsync0(() {});

      pause = Timer(const Duration(seconds: 3), wrapper);
    });

    test('7. Delete Document Offline docid3', () {
      print('9.7');
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.deletec);
        expect(res.id, '9docid3');
        expect(res.payload, isNull);
        expect(res.rev, isNull);
        expect(sporran9.pendingDeleteSize, 1);
      });

      sporran9.online = false;
      sporran9.delete('9docid3', docid3rev).then(wrapper);
    });

    test('8. Delete Attachment Offline docid1 Attachment1', () {
      print('9.8');
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.deleteAttachmentc);
        expect(res.id, '9docid1');
        expect(res.localResponse, isTrue);
        expect(res.rev, isNull);
      });

      sporran9
          .deleteAttachment('9docid1', 'AttachmentName1', docid1rev)
          .then(wrapper);
    });

    test('9. Put Document Offline Updated docid2', () {
      print('9.9');
      final dynamic wrapper2 = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putc);
        expect(res.localResponse, isTrue);
        expect(res.id, '9docid2');
        expect(res.rev, docid2rev);
        expect(res.payload.title, 'Document 2 Updated');
      });

      final dynamic wrapper1 = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.getc);
        expect(res.localResponse, isTrue);
        expect(res.id, '9docid2');
        final dynamic document2 = JsonObjectLite<dynamic>();
        document2.title = 'Document 2 Updated';
        document2.version = 2;
        document2.attribute = 'Doc 2 attribute Updated';
        sporran9.put('9docid2', document2, docid2rev).then(wrapper2);
      });

      sporran9.get('9docid2', docid2rev).then(wrapper1);
    });

    test('10. Put Document Offline docid4', () {
      print('9.10');
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putc);
        expect(res.localResponse, isTrue);
        expect(res.id, '9docid4');
        expect(res.rev, isNull);
        expect(res.payload.title, 'Document 4');
      });

      final dynamic document4 = JsonObjectLite<dynamic>();
      document4.title = 'Document 4';
      document4.version = 4;
      document4.attribute = 'Doc 4 attribute';
      sporran9.put('9docid4', document4, null).then(wrapper);
    });

    test('11. Sync Pause', () {
      print('9.11');
      final dynamic wrapper = expectAsync0(() {});

      pause = Timer(const Duration(seconds: 3), wrapper);
    });

    test('12. Transition to online', () {
      print('9.12');
      sporran9.online = true;
    });

    test('13. Sync Pause', () {
      print('9.13');
      final dynamic wrapper = expectAsync0(() {});

      pause = Timer(const Duration(seconds: 3), wrapper);
    });

    test('14. Check - Get All Docs Online', () {
      print('9.14');
      final dynamic wrapper = expectAsync1((dynamic res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.getAllDocsc);
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        final dynamic successResponse = res.payload;
        expect(successResponse.total_rows, equals(3));
        expect(successResponse.rows[0].id, equals('9docid1'));
        docid1rev = WiltUserUtils.getDocumentRev(successResponse.rows[0].doc);
        expect(successResponse.rows[0].doc.title, 'Document 1');
        expect(successResponse.rows[0].doc.version, 1);
        expect(successResponse.rows[0].doc.attribute, 'Doc 1 attribute');
        final doc1Attachments =
            WiltUserUtils.getAttachments(successResponse.rows[0].doc);
        expect(doc1Attachments.length, 1);
        expect(doc1Attachments[0]['name'], 'AttachmentName2');
        expect(successResponse.rows[1].id, equals('9docid2'));
        docid2rev = WiltUserUtils.getDocumentRev(successResponse.rows[1].doc);
        expect(successResponse.rows[1].doc.title, 'Document 2 Updated');
        expect(successResponse.rows[1].doc.version, 2);
        expect(
            successResponse.rows[1].doc.attribute, 'Doc 2 attribute Updated');
        final doc2Attachments =
            WiltUserUtils.getAttachments(successResponse.rows[1].doc);
        expect(doc2Attachments.length, 0);
        expect(successResponse.rows[2].id, equals('9docid4'));
        expect(successResponse.rows[2].doc.title, 'Document 4');
        expect(successResponse.rows[2].doc.version, 4);
        expect(successResponse.rows[2].doc.attribute, 'Doc 4 attribute');
        final doc4Attachments =
            WiltUserUtils.getAttachments(successResponse.rows[2].doc);
        expect(doc4Attachments, isEmpty);
      });

      sporran9.getAllDocs(includeDocs: true).then(wrapper);
    });
  });
}
