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
//import 'package:wilt/wilt.dart';
import 'package:unittest/unittest.dart';  
import 'package:unittest/html_config.dart';
import 'sporran_test_config.dart';

main() {  
  
  useHtmlConfiguration();
  
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
  
  group("9. Scenario Tests 2 - ", () {
    
    Sporran sporran9;
    String docid1rev;
    String docid2rev;
    String docid3rev;
    String attachmentPayload = 'iVBORw0KGgoAAAANSUhEUgAAABwAAAASCAMAAAB/2U7WAAAABl'+
        'BMVEUAAAD///+l2Z/dAAAASUlEQVR4XqWQUQoAIAxC2/0vXZDr'+
        'EX4IJTRkb7lobNUStXsB0jIXIAMSsQnWlsV+wULF4Avk9fLq2r'+
        '8a5HSE35Q3eO2XP1A1wQkZSgETvDtKdQAAAABJRU5ErkJggg==';
    
    test("1. Create and Open Sporran", () { 
      
      print("9.1");
      var wrapper = expectAsync0(() {
      
        expect(sporran9.dbName, databaseName);
        expect(sporran9.lawnIsOpen, isTrue);
        
      
      });
    
      sporran9 = new Sporran(databaseName,
        hostName,
        false,
        port,
        scheme,
        userName,
        userPassword);
    
    
      sporran9.onReady.first.then((e) => wrapper());  
  
    });
    
    test("2. Bulk Insert Documents Online", () { 
      
      print("9.2");
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran9.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.BULK_CREATE); 
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
        JsonObject doc3 = res.payload['9docid3'];
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
      docs['9docid1'] = document1;
      docs['9docid2'] = document2;
      docs['9docid3'] = document3;
      
      sporran9.clientCompleter = wrapper;
      sporran9.bulkCreate(docs);
      
      
    });
    
    test("3. Create Attachment Online docid1 Attachment 1", () { 
      
      print("9.3");
      var wrapper = expectAsync0(() {
      
        JsonObject res = sporran9.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT_ATTACHMENT); 
        expect(res.id, "9docid1");
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        docid1rev = res.rev;
        expect(res.payload.attachmentName,"AttachmentName1");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      
      });
    
      sporran9.clientCompleter = wrapper;
      JsonObject attachment = new JsonObject();
      attachment.attachmentName = "AttachmentName1";
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9.putAttachment("9docid1", 
                          attachment);
    
    
    });
    
    test("4. Create Attachment Online docid1 Attachment 2", () { 
      
      print("9.4");
      var wrapper = expectAsync0(() {
      
        JsonObject res = sporran9.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT_ATTACHMENT); 
        expect(res.id, "9docid1");
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        docid1rev = res.rev;
        expect(res.payload.attachmentName,"AttachmentName2");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      
      });
    
      sporran9.clientCompleter = wrapper;
      JsonObject attachment = new JsonObject();
      attachment.attachmentName = "AttachmentName2";
      attachment.rev = docid1rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9.putAttachment("9docid1", 
                          attachment);
    
    
    });
    
    
    test("5. Create Attachment Online docid2 Attachment 1", () { 
      
      print("9.5");
      var wrapper = expectAsync0(() {
      
        JsonObject res = sporran9.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT_ATTACHMENT); 
        expect(res.id, "9docid2");
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        docid2rev = res.rev;
        expect(res.payload.attachmentName,"AttachmentName1");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      
      });
    
      sporran9.clientCompleter = wrapper;
      JsonObject attachment = new JsonObject();
      attachment.attachmentName = "AttachmentName1";
      attachment.rev = docid2rev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran9.putAttachment("9docid2", 
                          attachment);
    
    
    });
    
     test("6. Sync Pause", () { 
      
      print("9.6");
      var wrapper = expectAsync0(() {});
      
      Timer pause = new Timer(new Duration(seconds:3), wrapper);
      
    });

    test("7. Delete Document Offline docid3", () { 
      
      print("9.7");
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran9.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.DELETE); 
        expect(res.id, "9docid3");
        expect(res.payload, isNull);
        expect(res.rev, isNull);
        expect(sporran9.pendingDeleteSize, 1);
      });
      
      sporran9.online = false;
      sporran9.clientCompleter = wrapper;
      sporran9.delete("9docid3",
                      docid3rev);
      
      
    });
    
    test("8. Delete Attachment Offline docid1 Attachment1", () { 
      
      print("9.8");
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran9.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.DELETE_ATTACHMENT); 
        expect(res.id, '9docid1');
        expect(res.localResponse, isTrue);
        expect(res.rev, isNull);
        
      });
      
      sporran9.clientCompleter = wrapper;
      sporran9.deleteAttachment('9docid1', 
                                "AttachmentName1",
                                docid1rev);
                                
    });
    
    test("9. Put Document Offline Updated docid2", () { 
      
      print("9.9");
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran9.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT); 
        expect(res.localResponse, isTrue);
        expect(res.id, '9docid2');
        expect(res.rev, docid2rev);
        expect(res.payload.title, "Document 2 Updated");
        
      });
      
      sporran9.clientCompleter = wrapper;
      JsonObject document2 = new JsonObject();
      document2.title = "Document 2 Updated";
      document2.version = 2;
      document2.attribute = "Doc 2 attribute Updated";
      sporran9.put('9docid2', 
                   document2,
                   docid2rev);
      
    });
    
    test("10. Put Document Offline New docid4", () { 
      
      print("9.10");
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran9.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT); 
        expect(res.localResponse, isTrue);
        expect(res.id, '9docid4');
        expect(res.rev, isNull);
        expect(res.payload.title, "Document 4");
        
      });
      
      sporran9.clientCompleter = wrapper;
      JsonObject document4 = new JsonObject();
      document4.title = "Document 4";
      document4.version = 4;
      document4.attribute = "Doc 4 attribute";
      sporran9.put('9docid4', 
                   document4,
                   null);
      
    });
    

    test("11. Sync Pause", () { 
      
      print("9.11");
      var wrapper = expectAsync0(() {});
      
      Timer pause = new Timer(new Duration(seconds:3), wrapper);
      
    });
    
    test("12. Transition to online", () { 
      
      print("9.12");
      sporran9.online = true;
           
    });
    
    test("13. Sync Pause", () { 
      
      print("9.13");
      var wrapper = expectAsync0(() {});
      
      Timer pause = new Timer(new Duration(seconds:3), wrapper);
      
    });
          
    /*test("14. Sync Pause", () { 
      
      print("9.14");
      var wrapper = expectAsync0(() {});
      
      Timer pause = new Timer(new Duration(seconds:3), wrapper);
      
    });*/
    
   /* test("11. Check - Get All Docs Online", () {  
      
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
      
      
    });*/
    
    

  });
  
}