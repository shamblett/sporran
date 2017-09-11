/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */
@TestOn("dartium")

import 'dart:async';

import 'package:sporran/sporran.dart';
import 'package:json_object/json_object.dart';
import 'package:test/test.dart';
import 'sporran_test_config.dart';

void main() {
  /* Common initialiser */
  final SporranInitialiser initialiser = new SporranInitialiser();
  initialiser.dbName = databaseName;
  initialiser.hostname = hostName;
  initialiser.manualNotificationControl = false;
  initialiser.port = port;
  initialiser.scheme = scheme;
  initialiser.username = userName;
  initialiser.password = userPassword;
  initialiser.preserveLocal = false;

  /* Group 9 - Sporran Scenario test 3 */
  /**
   *  Start offline
   *  Bulk create 3 docs
   *  Add two attachments
   *  Delete one document
   *  Kill sporran
   *  Construct a new sporran
   *  Check the documents above still exist
   */

  group("9. Scenario Tests 1 - ", () {
    Sporran sporran9;
    Sporran sporran10;
    String docid1rev;
    String docid2rev;
    String docid3rev;
    final String attachmentPayload =
        'iVBORw0KGgoAAAANSUhEUgAAABwAAAASCAMAAAB/2U7WAAAABl' +
            'BMVEUAAAD///+l2Z/dAAAASUlEQVR4XqWQUQoAIAxC2/0vXZDr' +
            'EX4IJTRkb7lobNUStXsB0jIXIAMSsQnWlsV+wULF4Avk9fLq2r' +
            '8a5HSE35Q3eO2XP1A1wQkZSgETvDtKdQAAAABJRU5ErkJggg==';

    test("1. Create and Open Sporran", () {
      print("9.1");
      final wrapper = expectAsync0(() {
        expect(sporran9.dbName, databaseName);
        expect(sporran9.lawnIsOpen, isTrue);
        sporran9.online = false;
      });

      sporran9 = new Sporran(initialiser);
      sporran9.onReady.first.then((e) => wrapper());
    });

    test("2. Bulk Insert Documents Offline", () {
      print("9.2");
      final wrapper = expectAsync1((res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.bulkCreatec);
        expect(res.id, isNull);
        expect(res.payload, isNotNull);
        expect(res.rev, isNull);
        final JsonObject doc3 = res.payload['8docid3'];
        expect(doc3.title, "Document 3");
        expect(doc3.version, 3);
        expect(doc3.attribute, "Doc 3 attribute");
      });

      final JsonObject document1 = new JsonObject();
      document1.title = "Document 1";
      document1.version = 1;
      document1.attribute = "Doc 1 attribute";

      final JsonObject document2 = new JsonObject();
      document2.title = "Document 2";
      document2.version = 2;
      document2.attribute = "Doc 2 attribute";

      final JsonObject document3 = new JsonObject();
      document3.title = "Document 3";
      document3.version = 3;
      document3.attribute = "Doc 3 attribute";

      final Map docs = new Map<String, JsonObject>();
      docs['8docid1'] = document1;
      docs['8docid2'] = document2;
      docs['8docid3'] = document3;

      sporran9.bulkCreate(docs)
        ..then((res) {
          wrapper(res);
        });
    });

    test("3. Create Attachment Offline docid1 Attachment 1", () {
      print("9.3");
      final wrapper = expectAsync1((res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, "8docid1");
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        docid1rev = res.rev;
        expect(res.payload.attachmentName, "AttachmentName1");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      final JsonObject attachment = new JsonObject();
      attachment.attachmentName = "AttachmentName1";
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9.putAttachment("8docid1", attachment)
        ..then((res) {
          wrapper(res);
        });
    });

    test("4. Create Attachment Offline docid1 Attachment 2", () {
      print("9.4");
      final wrapper = expectAsync1((res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, "8docid1");
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        docid1rev = res.rev;
        expect(res.payload.attachmentName, "AttachmentName2");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      final JsonObject attachment = new JsonObject();
      attachment.attachmentName = "AttachmentName2";
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9.putAttachment("8docid1", attachment)
        ..then((res) {
          wrapper(res);
        });
    });

    test("5. Create Attachment Offline docid2 Attachment 1", () {
      print("9.5");
      final wrapper = expectAsync1((res) {
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.putAttachmentc);
        expect(res.id, "8docid2");
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        docid2rev = res.rev;
        expect(res.payload.attachmentName, "AttachmentName1");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      });

      final JsonObject attachment = new JsonObject();
      attachment.attachmentName = "AttachmentName1";
      attachment.rev = docid2rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9.putAttachment("8docid2", attachment)
        ..then((res) {
          wrapper(res);
        });
    });

    test("6. Delete Document Offline docid3", () {
      print("9.6");
      final wrapper = expectAsync1((res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.deletec);
        expect(res.id, "8docid3");
        expect(res.payload, isNull);
        expect(res.rev, isNull);
        expect(sporran9.pendingDeleteSize, 1);
      });

      sporran9.delete("8docid3", docid3rev)
        ..then((res) {
          wrapper(res);
        });
    });

    test("7. Check - Get All Docs Offline - Existing Sporran", () {
      print("9.7");
      final wrapper = expectAsync1((res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.getAllDocsc);
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        expect(res.totalRows, equals(2));
        final List keyList = res.keyList;
        expect(keyList[0], '8docid1');
        expect(keyList[1], '8docid2');
        expect(res.payload[keyList[0]].key, equals('8docid1'));
        expect(res.payload[keyList[0]].payload.title, "Document 1");
        expect(res.payload[keyList[0]].payload.version, 1);
        expect(res.payload[keyList[0]].payload.attribute, "Doc 1 attribute");
        expect(res.payload[keyList[1]].key, equals('8docid2'));
        expect(res.payload[keyList[1]].payload.title, "Document 2");
        expect(res.payload[keyList[1]].payload.version, 2);
        expect(res.payload[keyList[1]].payload.attribute, "Doc 2 attribute");
        /* Kill this sporran */
        sporran9 = null;
      });
      final List<String> keys = null;
      sporran9.getAllDocs(includeDocs: true, keys: keys)
        ..then((res) {
          wrapper(res);
        });
    });

    test("8. Check - Get All Docs Offline -  New Sporran", () {
      print("9.8");
      final wrapper1 = expectAsync1((res) {
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.getAllDocsc);
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        expect(res.totalRows, equals(2));
        final List keyList = res.keyList;
        expect(keyList[0], '8docid1');
        expect(keyList[1], '8docid2');
        expect(res.payload[keyList[0]].key, equals('8docid1'));
        expect(res.payload[keyList[0]].payload.title, "Document 1");
        expect(res.payload[keyList[0]].payload.version, 1);
        expect(res.payload[keyList[0]].payload.attribute, "Doc 1 attribute");
        expect(res.payload[keyList[1]].key, equals('8docid2'));
        expect(res.payload[keyList[1]].payload.title, "Document 2");
        expect(res.payload[keyList[1]].payload.version, 2);
        expect(res.payload[keyList[1]].payload.attribute, "Doc 2 attribute");
      });

      final wrapper = expectAsync0(() {
        expect(sporran10.dbName, databaseName);
        expect(sporran10.lawnIsOpen, isTrue);
        sporran10.online = false;

        final List<String> keys = null;
        sporran10.getAllDocs(includeDocs: true, keys: keys)
          ..then((res) {
            wrapper1(res);
          });
      });

      initialiser.preserveLocal = true;
      sporran10 = new Sporran(initialiser);
      sporran10.onReady.first.then((e) => wrapper());
    });
  });
}
