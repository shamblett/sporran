/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */

library sporran_test;

import 'dart:async';

import '../lib/sporran.dart';
import 'package:json_object/json_object.dart';
import 'package:wilt/wilt.dart';
import 'package:unittest/unittest.dart';  
import 'package:unittest/html_config.dart';
import 'sporran_test_config.dart';

main() {  
  
  useHtmlConfiguration();
  
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
  
  group("8. Scenario Tests 1 - ", () {
    
    Sporran sporran8;
    String docid1rev;
    String docid2rev;
    String docid3rev;
    String attachmentPayload = 'iVBORw0KGgoAAAANSUhEUgAAABwAAAASCAMAAAB/2U7WAAAABl'+
        'BMVEUAAAD///+l2Z/dAAAASUlEQVR4XqWQUQoAIAxC2/0vXZDr'+
        'EX4IJTRkb7lobNUStXsB0jIXIAMSsQnWlsV+wULF4Avk9fLq2r'+
        '8a5HSE35Q3eO2XP1A1wQkZSgETvDtKdQAAAABJRU5ErkJggg==';
    
    test("1. Create and Open Sporran", () { 
      
      print("8.1");
      var wrapper = expectAsync0(() {
      
        expect(sporran8.dbName, databaseName);
        expect(sporran8.lawnIsOpen, isTrue);
        sporran8.online = false;
        
      
      });
    
      sporran8 = new Sporran(databaseName,
        hostName,
        true,
        port,
        scheme,
        userName,
        userPassword);
    
    
      sporran8.onReady.first.then((e) => wrapper());  
  
    });
    
    test("2. Bulk Insert Documents Offline", () { 
      
      print("8.2");
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran8.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.BULK_CREATE); 
        expect(res.id, isNull);
        expect(res.payload, isNotNull);
        expect(res.rev, isNull);
        JsonObject doc3 = res.payload['docid3'];
        expect(doc3.title, "Document 3");
        expect(doc3.version,3);
        expect(doc3.attribute, "Doc 3 attribute");
       
      });
      
      JsonObject document1 = new JsonObject();
      document1.title = "Document 1";
      document1.version = 1;
      document1.attribute = "Doc 1 attribute";
      
      JsonObject document2 = new JsonObject();
      document2.title = "Document 2";
      document2.version = 2;
      document2.attribute = "Doc 2 attribute";
      
      JsonObject document3 = new JsonObject();
      document3.title = "Document 3";
      document3.version = 3;
      document3.attribute = "Doc 3 attribute";
      
      Map docs = new Map<String, JsonObject>();
      docs['docid1'] = document1;
      docs['docid2'] = document2;
      docs['docid3'] = document3;
      
      sporran8.clientCompleter = wrapper;
      sporran8.bulkCreate(docs);
      
      
    });
    
    test("3. Create Attachment Offline docid1 Attachment 1", () { 
      
      print("8.3");
      var wrapper = expectAsync0(() {
      
        JsonObject res = sporran8.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT_ATTACHMENT); 
        expect(res.id, "docid1");
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        docid1rev = res.rev;
        expect(res.payload.attachmentName,"AttachmentName1");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      
      });
    
      sporran8.clientCompleter = wrapper;
      JsonObject attachment = new JsonObject();
      attachment.attachmentName = "AttachmentName1";
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran8.putAttachment("docid1", 
                          attachment);
    
    
    });
    
    test("4. Create Attachment Offline docid1 Attachment 2", () { 
      
      print("8.4");
      var wrapper = expectAsync0(() {
      
        JsonObject res = sporran8.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT_ATTACHMENT); 
        expect(res.id, "docid1");
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        docid1rev = res.rev;
        expect(res.payload.attachmentName,"AttachmentName2");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      
      });
    
      sporran8.clientCompleter = wrapper;
      JsonObject attachment = new JsonObject();
      attachment.attachmentName = "AttachmentName2";
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran8.putAttachment("docid1", 
                          attachment);
    
    
    });
    
    
    test("5. Create Attachment Offline docid2 Attachment 1", () { 
      
      print("8.5");
      var wrapper = expectAsync0(() {
      
        JsonObject res = sporran8.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT_ATTACHMENT); 
        expect(res.id, "docid2");
        expect(res.localResponse, isTrue);
        expect(res.rev, anything);
        docid2rev = res.rev;
        expect(res.payload.attachmentName,"AttachmentName1");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      
      });
    
      sporran8.clientCompleter = wrapper;
      JsonObject attachment = new JsonObject();
      attachment.attachmentName = "AttachmentName1";
      attachment.rev = docid2rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran8.putAttachment("docid2", 
                          attachment);
    
    
    });
    

    test("6. Delete Document Offline docid3", () { 
      
      print("8.6");
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran8.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.DELETE); 
        expect(res.id, "docid3");
        expect(res.payload, isNull);
        expect(res.rev, isNull);
        expect(sporran8.pendingDeleteSize, 1);
      });
      
      sporran8.clientCompleter = wrapper;
      sporran8.delete("docid3",
                      docid3rev);
      
      
    });
    
    test("7. Sync Pause", () { 
      
      print("8.7");
      var wrapper = expectAsync0(() {});
      
      Timer pause = new Timer(new Duration(seconds:3), wrapper);
      
    });
    
    test("8. Transition to online", () { 
      
      print("8.8");
      sporran8.online = true;
           
    });
    
    test("9. Sync Pause", () { 
      
      print("8.9");
      var wrapper = expectAsync0(() {});
      
      Timer pause = new Timer(new Duration(seconds:3), wrapper);
      
    });
          
    test("10. Sync Pause", () { 
      
      print("8.10");
      var wrapper = expectAsync0(() {});
      
      Timer pause = new Timer(new Duration(seconds:3), wrapper);
      
    });
    
    test("11. Check - Get All Docs Online", () {  
      
      print("8.11");
      var wrapper = expectAsync0((){
      
        JsonObject res = sporran8.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.GET_ALL_DOCS); 
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        JsonObject successResponse = res.payload;
        expect(successResponse.total_rows, equals(2));
        expect(successResponse.rows[0].id, equals('docid1'));
        docid1rev = WiltUserUtils.getDocumentRev(successResponse.rows[0].doc);
        expect(successResponse.rows[1].id, equals('docid2'));
        docid2rev = WiltUserUtils.getDocumentRev(successResponse.rows[1].doc);
        expect(successResponse.rows[0].doc.title, "Document 1" );
        expect(successResponse.rows[0].doc.version, 1);
        expect(successResponse.rows[0].doc.attribute,"Doc 1 attribute");
        List doc1Attachments = WiltUserUtils.getAttachments(successResponse.rows[0].doc);
        expect(doc1Attachments.length, 2);
        expect(successResponse.rows[1].doc.title, "Document 2" );
        expect(successResponse.rows[1].doc.version, 2);
        expect(successResponse.rows[1].doc.attribute,"Doc 2 attribute");
        List doc2Attachments = WiltUserUtils.getAttachments(successResponse.rows[1].doc);
        expect(doc2Attachments.length, 1);
      
      });
    
      sporran8.clientCompleter = wrapper;
      sporran8.getAllDocs(includeDocs:true);
    
    
    }); 
    
    test("12. Delete Document Online docid1", () { 
      
      print("8.12");
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran8.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.DELETE); 
        expect(res.id, 'docid1');
        expect(res.payload, isNotNull);
        expect(res.rev, anything);
        
      });
      
      sporran8.clientCompleter = wrapper;
      sporran8.delete('docid1',
                       docid1rev);
      
      
    });
    
    test("13. Delete Document Online docid2", () { 
      
      print("8.13");
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran8.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.DELETE); 
        expect(res.id, 'docid2');
        expect(res.payload, isNotNull);
        expect(res.rev, anything);
        
      });
      
      sporran8.clientCompleter = wrapper;
      sporran8.delete('docid2',
                       docid2rev);
      
      
    });
    
    

  });
  
}