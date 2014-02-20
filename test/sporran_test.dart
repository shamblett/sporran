/*
 * Package : Sporran
 * Author : S. Hamblett <steve.hamblett@linux.com>
 * Date   : 05/02/2014
 * Copyright :  S.Hamblett@OSCF
 */

library sporran_test;

import 'dart:async';
import 'dart:html';

import '../lib/sporran.dart';
import 'package:json_object/json_object.dart';
import 'package:wilt/wilt.dart';
import 'package:unittest/unittest.dart';  
import 'package:unittest/html_config.dart';
import 'sporran_test_config.dart';

main() {  
  
  useHtmlConfiguration();
  
  
  /* Group 1 - Environment tests */
  group("1. Environment Tests - ", () {
    
    String status = "online";
    
    test("Online/Offline", () {  
      
      window.onOffline.listen((e){
        
        expect(status, "offline");
        /* Because we aren't really offline */
        expect(window.navigator.onLine, isTrue);
        
      });
      
      window.onOnline.listen((e){
        
        expect(status, "online");
        expect(window.navigator.onLine, isTrue);
        
      });
      
      status = "offline";
      var e = new Event.eventType('Event', 'offline');
      window.dispatchEvent(e);
      status = "online";
      e = new Event.eventType('Event', 'online');
      window.dispatchEvent(e);
      
      
    });  
    
  });
  
  /* Group 2 - Sporran constructor tests */
  group("2. Constructor Tests - ", () {
    
    
    test("Construction New Database ", () {  
      
      void wrapper() {
        
        Sporran sporran = new Sporran(databaseName,
            hostName,
            port,
            scheme,
            userName,
            userPassword);
        
        expect(sporran, isNotNull);
        expect(sporran.dbName, databaseName);
        
      };
      

      expect(wrapper, returnsNormally);
     
      
    });
    
    test("Construction Existing Database ", () {  
      
      void wrapper() {
        
        
        Sporran sporran = new Sporran(databaseName,
            hostName,
            port,
            scheme,
            userName,
            userPassword);
        
        expect(sporran, isNotNull);
        expect(sporran.dbName, databaseName);
        
      };
      

      expect(wrapper, returnsNormally);
     
      
    });
    
    test("Construction Invalid Database ", () {  
      
      void wrapper() {
        
        Sporran sporran = new Sporran('freddy',
            hostName,
            port,
            scheme,
            userName,
            'notreal');
        
        expect(sporran, isNotNull); 
          
        };
     
      expect(wrapper, returnsNormally);
     
      
    });
    
    test("Construction Online/Offline listener ", () {  
        

      Sporran sporran = new Sporran(databaseName,
            hostName,
            port,
            scheme,
            userName,
            userPassword);
      
      var wrapper = expectAsync0(() {
        
        Event offline = new Event.eventType('Event', 'offline');
        window.dispatchEvent(offline);
        expect(sporran.online, isFalse); 
        Event online = new Event.eventType('Event', 'online');
        window.dispatchEvent(online);
        expect(sporran.online, isTrue); 
        
        
      });     
          
      expect(sporran, isNotNull);
      expect(sporran.online, isFalse);
      sporran.onReady.listen((e) => wrapper());
      
    });
    
   
  });    
  
  /* Group 3 - Sporran document put/get tests */
  group("3. Document Put/Get/Delete Tests - ", () {
    
    Sporran sporran;
    
    String docIdPutOnline = "putOnline";
    String docIdPutOffline = "putOffline";
    JsonObject onlineDoc = new JsonObject();
    JsonObject offlineDoc = new JsonObject();
    String onlineDocRev;
    
    test("Create and Open Sporran", () { 
      
    
    var wrapper = expectAsync0(() {
      
      expect(sporran.dbName, databaseName);
      expect(sporran.lawnIsOpen, isTrue);
      
    });
    
    sporran = new Sporran(databaseName,
        hostName,
        port,
        scheme,
        userName,
        userPassword);
    
    
    sporran.onReady.listen((e) => wrapper());
  
    });
    
     test("Put Document Online docIdPutOnline", () { 
      
     
      var wrapper = expectAsync0(() {
                    
          JsonObject res = sporran.completionResponse;
          expect(res.ok, isTrue);
          expect(res.operation, Sporran.PUT); 
          expect(res.localResponse, isFalse);
          expect(res.id, docIdPutOnline);
          expect(res.rev, anything);
          onlineDocRev = res.rev;
          expect(res.payload.name, "Online");
        
      });
      
      sporran.online = true;
      sporran.clientCompleter = wrapper;
      onlineDoc.name = "Online";
      sporran.put(docIdPutOnline, 
                  onlineDoc);
                                
      
    });
  
  test("Put Document Offline docIdPutOffline", () { 
    
    var wrapper = expectAsync0(() {
      
      JsonObject res = sporran.completionResponse;
      expect(res.ok, isTrue);
      expect(res.operation, Sporran.PUT);  
      expect(res.localResponse, isTrue);
      expect(res.id, docIdPutOffline);
      expect(res.payload.name, "Offline");
      
    });
    
    sporran.online = false;
    sporran.clientCompleter = wrapper;
    offlineDoc.name = "Offline";
    sporran.put(docIdPutOffline, 
        offlineDoc);
    
    
  });
  
   
   test("Put Document Online Conflict", () { 
     
     
     var wrapper = expectAsync0(() {
       
       JsonObject res = sporran.completionResponse;
       expect(res.errorCode, 409);
       expect(res.errorText, 'conflict');
       expect(res.operation, Sporran.PUT); 
       expect(res.id, docIdPutOnline);
      
       
     });
     
     sporran.online = true;
     sporran.clientCompleter = wrapper;
     onlineDoc.name = "Online";
     sporran.put(docIdPutOnline,onlineDoc);                                   
     
   });
   
   test("Put Document Online Updated docIdPutOnline", () { 
     
     
     var wrapper = expectAsync0(() {
       
       JsonObject res = sporran.completionResponse;
       expect(res.ok, isTrue);
       expect(res.operation, Sporran.PUT); 
       expect(res.localResponse, isFalse);
       expect(res.id, docIdPutOnline);
       expect(res.rev, anything);
       expect(res.payload.name, "Online - Updated");
       
     });
     
     sporran.online = true;
     sporran.clientCompleter = wrapper;
     onlineDoc.name = "Online - Updated";
     sporran.put(docIdPutOnline, 
                 onlineDoc,
                 onlineDocRev);
     
     
   });
   
   test("Get Document Offline docIdPutOnline", () { 
     
     var wrapper = expectAsync0(() {
       
       JsonObject res = sporran.completionResponse;
       expect(res.ok, isTrue);
       expect(res.operation, Sporran.GET); 
       expect(res.localResponse, isTrue);
       expect(res.id, docIdPutOnline);
       expect(res.payload.name, "Online - Updated");
       
     });
     
     sporran.online = false;
     sporran.clientCompleter = wrapper;
     sporran.get(docIdPutOnline);
     
     
   });
   
   test("Get Document Offline docIdPutOffline", () { 
     
     var wrapper = expectAsync0(() {
       
       JsonObject res = sporran.completionResponse;
       expect(res.ok, isTrue);
       expect(res.operation, Sporran.GET);  
       expect(res.localResponse, isTrue);
       expect(res.id, docIdPutOffline);
       expect(res.payload.name, "Offline");
       expect(res.rev, isNull);
       
     });
     
     sporran.online = false;
     sporran.clientCompleter = wrapper;
     sporran.get(docIdPutOffline);
     
     
   });

   test("Get Document Offline Not Exist", () { 
     
     var wrapper = expectAsync0(() {
       
       JsonObject res = sporran.completionResponse;
       expect(res.ok, isFalse);
       expect(res.operation, Sporran.GET); 
       expect(res.localResponse, isTrue);
       expect(res.id, "Billy");
       expect(res.rev, isNull);
       expect(res.payload, isNull);
       
     });
     
     sporran.online = false;
     sporran.clientCompleter = wrapper;
     offlineDoc.name = "Offline";
     sporran.get("Billy");
     expect(sporran.hotCacheSize, 0);
     
     
   });
   
   test("Get Document Online docIdPutOnline", () { 
     
     var wrapper = expectAsync0(() {
       
       JsonObject res = sporran.completionResponse;
       expect(res.ok, isTrue);
       expect(res.operation, Sporran.GET);  
       expect(res.payload.name, "Online - Updated");
       expect(res.localResponse, isFalse);
       expect(res.id, docIdPutOnline);
       onlineDocRev = res.rev;
       
     });
     
     sporran.online = true;;
     sporran.clientCompleter = wrapper;
     sporran.get(docIdPutOnline);
     
     
   });
    
    test("Get Document Online Not Exist", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.GET);
        expect(res.localResponse, isFalse);
        expect(res.id, "Billy");
        
      });
      
      sporran.online = true;;
      sporran.clientCompleter = wrapper;
      sporran.get("Billy");
      
      
    }); 
    
    
    test("Delete Document Not Exist", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.DELETE); 
        expect(res.id, "Billy");
        expect(res.payload, isNull);
        expect(res.rev, isNull);
        
      });
      
      sporran.online = false;;
      sporran.clientCompleter = wrapper;
      sporran.delete("Billy");
      
      
    }); 
     
     test("Delete Document Offline", () { 
       
       var wrapper = expectAsync0(() {
         
         JsonObject res = sporran.completionResponse;
         expect(res.ok, isTrue);
         expect(res.localResponse, isTrue);
         expect(res.operation, Sporran.DELETE); 
         expect(res.id, docIdPutOffline);
         expect(res.payload, isNull);
         expect(res.rev, isNull);
         expect(sporran.pendingDeleteSize, 1);
         
       });
       
       sporran.online = false;
       sporran.clientCompleter = wrapper;
       sporran.delete(docIdPutOffline);
       
       
     }); 
     
     test("Delete Document Online", () { 
       
       var wrapper = expectAsync0(() {
         
         JsonObject res = sporran.completionResponse;
         expect(res.ok, isTrue);
         expect(res.localResponse, isFalse);
         expect(res.operation, Sporran.DELETE); 
         expect(res.id, docIdPutOnline);
         expect(res.payload, isNotNull);
         expect(res.rev, anything);
         expect(sporran.pendingDeleteSize, 1);
         
       });
       
       sporran.online = true;
       sporran.clientCompleter = wrapper;
       sporran.delete(docIdPutOnline,
                      onlineDocRev);
       
       
     });
    
  });
  
  /* Group 4 - Sporran attachment put/get tests */
  group("4. Attachment Put/Get/Delete Tests - ", () {
    
    Sporran sporran;
    
    String docIdPutOnline = "putOnline";
    String docIdPutOffline = "putOffline";
    JsonObject onlineDoc = new JsonObject();
    JsonObject offlineDoc = new JsonObject();
    String onlineDocRev;
    
    String attachmentPayload = 'iVBORw0KGgoAAAANSUhEUgAAABwAAAASCAMAAAB/2U7WAAAABl'+
                               'BMVEUAAAD///+l2Z/dAAAASUlEQVR4XqWQUQoAIAxC2/0vXZDr'+
                               'EX4IJTRkb7lobNUStXsB0jIXIAMSsQnWlsV+wULF4Avk9fLq2r'+
                               '8a5HSE35Q3eO2XP1A1wQkZSgETvDtKdQAAAABJRU5ErkJggg==';
    
    
    test("Create and Open Sporran", () { 
      
    
    var wrapper = expectAsync0(() {
      
      expect(sporran.dbName, databaseName);
      expect(sporran.lawnIsOpen, isTrue);
      
    });
    
    sporran = new Sporran(databaseName,
        hostName,
        port,
        scheme,
        userName,
        userPassword);
    
    
    sporran.onReady.listen((e) => wrapper());  
  
    });
    
    test("Put Document Online docIdPutOnline", () { 
      
     
      var wrapper = expectAsync0(() {
                    
          JsonObject res = sporran.completionResponse;
          expect(res.ok, isTrue);
          expect(res.operation, Sporran.PUT);
          expect(res.id, docIdPutOnline);
          expect(res.localResponse, isFalse);
          expect(res.payload.name, "Online");
          expect(res.rev, anything);
          onlineDocRev = res.rev;
          
        
      });
      
      sporran.online = true;
      sporran.clientCompleter = wrapper;
      onlineDoc.name = "Online";
      sporran.put(docIdPutOnline, 
                  onlineDoc);
                                
      
    });
  
    test("Put Document Offline docIdPutOffline", () { 
    
      var wrapper = expectAsync0(() {
      
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT); 
        expect(res.id, docIdPutOffline);
        expect(res.localResponse, isTrue);
        expect(res.payload.name, "Offline");
      
    });
    
    sporran.online = false;
    sporran.clientCompleter = wrapper;
    offlineDoc.name = "Offline";
    sporran.put(docIdPutOffline, 
        offlineDoc);
    
    
    });
  
    test("Create Attachment Online docIdPutOnline", () { 
    
      var wrapper = expectAsync0(() {
      
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT_ATTACHMENT); 
        expect(res.id, docIdPutOnline);
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        onlineDocRev = res.rev;
        expect(res.payload.attachmentName,"onlineAttachment");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
      
      });
    
    sporran.online = true;
    sporran.clientCompleter = wrapper;
    JsonObject attachment = new JsonObject();
    attachment.attachmentName = "onlineAttachment";
    attachment.rev = onlineDocRev;
    attachment.contentType = 'image/png';
    attachment.payload = attachmentPayload;
    sporran.putAttachment(docIdPutOnline, 
                          attachment);
    
    
    });
    
    test("Create Attachment Offline docIdPutOffline", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.PUT_ATTACHMENT);  
        expect(res.id, docIdPutOffline);
        expect(res.localResponse, isTrue);
        expect(res.rev, isNull);
        expect(res.payload.attachmentName,"offlineAttachment");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
        
      });
      
      sporran.online = false;
      sporran.clientCompleter = wrapper;
      JsonObject attachment = new JsonObject();
      attachment.attachmentName = "offlineAttachment";
      attachment.rev = onlineDocRev;
      attachment.contentType = 'image/png';
      attachment.payload = attachmentPayload;
      sporran.putAttachment(docIdPutOffline, 
                            attachment);
      
      
    });
    
    test("Get Attachment Online docIdPutOnline", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.GET_ATTACHMENT); 
        expect(res.id, docIdPutOnline);
        expect(res.localResponse, isFalse);
        expect(res.rev, anything);
        expect(res.payload.attachmentName,"onlineAttachment");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
        
      });
      
      sporran.online = true;
      sporran.clientCompleter = wrapper;
      sporran.getAttachment(docIdPutOnline, 
                            "onlineAttachment");
      
      
    });
    
    test("Get Attachment Offline docIdPutOffline", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.GET_ATTACHMENT); 
        expect(res.id, docIdPutOffline);
        expect(res.localResponse, isTrue);
        expect(res.rev, isNull);
        expect(res.payload.attachmentName,"offlineAttachment");
        expect(res.payload.contentType, 'image/png');
        expect(res.payload.payload, attachmentPayload);
        
      });
      
      sporran.online = false;
      sporran.clientCompleter = wrapper;
      sporran.getAttachment(docIdPutOffline, 
                            "offlineAttachment");
      
      
    });
    
    test("Delete Attachment Online docIdPutOnline", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.DELETE_ATTACHMENT); 
        expect(res.id, docIdPutOnline);
        expect(res.localResponse, isFalse);
        onlineDocRev = res.rev;
        expect(res.rev, anything);
        
        
      });
      
      sporran.online = true;
      sporran.clientCompleter = wrapper;
      sporran.deleteAttachment(docIdPutOnline, 
                               "onlineAttachment",
                                onlineDocRev);
                                
    });
    
    test("Delete Attachment Offline docIdPutOffline", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.DELETE_ATTACHMENT); 
        expect(res.id, docIdPutOffline);
        expect(res.localResponse, isTrue);
        expect(res.rev, isNull);
        expect(res.payload, isNull);
        
        
      });
      
      sporran.online = false;
      sporran.clientCompleter = wrapper;
      sporran.deleteAttachment(docIdPutOffline, 
                               "offlineAttachment",
                                null);
                                
    });
    
    test("Delete Attachment Not Exist", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.DELETE_ATTACHMENT); 
        expect(res.id, docIdPutOffline);
        expect(res.localResponse, isTrue);
        expect(res.rev, isNull);
        expect(res.payload, isNull);
        
        
      });
      
      sporran.online = false;
      sporran.clientCompleter = wrapper;
      sporran.deleteAttachment(docIdPutOffline, 
                               "Billy",
                                null);
                                
    });
    
    test("Delete Document Online", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.DELETE); 
        expect(res.id, docIdPutOnline);
        expect(res.payload, isNotNull);
        expect(res.rev, anything);
        
      });
      
      sporran.online = true;
      sporran.clientCompleter = wrapper;
      sporran.delete(docIdPutOnline,
                     onlineDocRev);
      
      
    });
  
  });
  
  /* Group 5 - Sporran Bulk Documents tests */
  group("5. Bulk Document Tests - ", () {
    
    Sporran sporran;
    String docid1rev;
    String docid2rev;
    String docid3rev;
    
    test("Create and Open Sporran", () { 
      
    
    var wrapper = expectAsync0(() {
      
      expect(sporran.dbName, databaseName);
      expect(sporran.lawnIsOpen, isTrue);
      
    });
    
    sporran = new Sporran(databaseName,
        hostName,
        port,
        scheme,
        userName,
        userPassword);
    
    
    sporran.onReady.listen((e) => wrapper());  
  
    });
    
    test("Bulk Insert Documents Online", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.BULK_CREATE); 
        expect(res.id, isNull);
        expect(res.payload, isNotNull);
        expect(res.rev, isNotNull);
        expect(res.rev[0], anything);
        docid1rev = res.rev[0];
        expect(res.rev[1], anything);
        docid2rev = res.rev[1];
        expect(res.rev[2], anything);
        docid3rev = res.rev[2];
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
      
      sporran.online = true;
      sporran.clientCompleter = wrapper;
      sporran.bulkCreate(docs);
      
      
    });
    
  test("Bulk Insert Documents Offline", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isTrue);
        expect(res.operation, Sporran.BULK_CREATE); 
        expect(res.id, isNull);
        expect(res.payload, isNotNull);
        expect(res.rev, isNull);
        JsonObject doc3 = res.payload['docid3offline'];
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
      docs['docid1offline'] = document1;
      docs['docid2offline'] = document2;
      docs['docid3offline'] = document3;
      
      sporran.online = false;
      sporran.clientCompleter = wrapper;
      sporran.bulkCreate(docs);
      
      
    });
  
  test("Get All Docs Online", () {  
    
    var wrapper = expectAsync0((){
      
      JsonObject res = sporran.completionResponse;
      expect(res.ok, isTrue);
      expect(res.localResponse, isFalse);
      expect(res.operation, Sporran.GET_ALL_DOCS); 
      expect(res.id, isNull);
      expect(res.rev, isNull);
      expect(res.payload, isNotNull);
      JsonObject successResponse = res.payload;
      expect(successResponse.total_rows, equals(3));
      expect(successResponse.rows[0].id, equals('docid1'));
      expect(successResponse.rows[1].id, equals('docid2'));
      expect(successResponse.rows[2].id, equals('docid3'));
      
    });
    
    sporran.online = true;
    sporran.clientCompleter = wrapper;
    sporran.getAllDocs(includeDocs:true);
    
    
  }); 
  
  test("Get All Docs Offline", () {  
    
    var wrapper = expectAsync0((){
      
      JsonObject res = sporran.completionResponse;
      expect(res.ok, isTrue);
      expect(res.localResponse, isTrue);
      expect(res.operation, Sporran.GET_ALL_DOCS); 
      expect(res.id, isNull);
      expect(res.rev, isNull);
      expect(res.payload, isNotNull);
      expect(res.payload.length, 6);
      expect(res.payload['docid1'].payload.title, "Document 1");
      expect(res.payload['docid2'].payload.title, "Document 2");
      expect(res.payload['docid3'].payload.title, "Document 3");
      expect(res.payload['docid1offline'].payload.title, "Document 1");
      expect(res.payload['docid2offline'].payload.title, "Document 2");
      expect(res.payload['docid3offline'].payload.title, "Document 3");
      
    });
    
    sporran.online = false;
    sporran.clientCompleter = wrapper;
    List keys = ['docid1offline', 'docid2offline', 'docid3offline',
                 'docid1', 'docid2', 'docid3'];
    
    sporran.getAllDocs(keys:keys);
    
    
  }); 
  
    test("Get Database Info Offline", () {  
    
    var wrapper = expectAsync0((){
      
      JsonObject res = sporran.completionResponse;
      expect(res.ok, isTrue);
      expect(res.localResponse, isTrue);
      expect(res.operation, Sporran.DB_INFO); 
      expect(res.id, isNull);
      expect(res.rev, isNull);
      expect(res.payload, isNotNull);
      expect(res.payload.length, 6);
      expect(res.payload.contains('docid1'), isTrue);
      expect(res.payload.contains('docid2'), isTrue);
      expect(res.payload.contains('docid3'), isTrue);
      expect(res.payload.contains('docid1offline'), isTrue);
      expect(res.payload.contains('docid2offline'), isTrue);
      expect(res.payload.contains('docid3offline'), isTrue);
      
    });
    
    sporran.online = false;
    sporran.clientCompleter = wrapper;
    
    sporran.getDatabaseInfo();
    
    
  }); 
  
    test("Get Database Info Online", () {  
      
      var wrapper = expectAsync0((){
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.localResponse, isFalse);
        expect(res.operation, Sporran.DB_INFO); 
        expect(res.id, isNull);
        expect(res.rev, isNull);
        expect(res.payload, isNotNull);
        expect(res.payload.doc_count, 3);
        expect(res.payload.db_name, databaseName);    
        
      });
      
      sporran.online = true;
      sporran.clientCompleter = wrapper;
      
      sporran.getDatabaseInfo();
      
      
    }); 
    
  test("Tidy Up All Docs Online", () {  
    
    var wrapper = expectAsync0((){
  
    
    
    },count:3);
    
    sporran.online = true;
    sporran.clientCompleter = wrapper;
    sporran.delete('docid1', docid1rev);
    sporran.delete('docid2', docid2rev);
    sporran.delete('docid3', docid3rev);
    
  });
  
  });
  
  /* Group 6 - Sporran Change notification tests */
  solo_group("6. Change notification Tests - ", () {
    
    Sporran sporran;
    
    /* We use Wilt here to change the CouchDb database independently
     * of Sporran, these change will be picked up in change notifications.
     */
    
    /* Create our Wilt */
    Wilt wilting = new Wilt(hostName, 
        port,
        scheme);
   
   /* Login if we are using authentication */
    if ( userName != null ) {
      
      wilting.login(userName,
                    userPassword);
    }
    
    wilting.db = databaseName;
    String docId1Rev;
    String docId2Rev;
    String docId3Rev;
    
    test("Create and Open Sporran", () { 
      
    
    var wrapper = expectAsync0(() {
      
      expect(sporran.dbName, databaseName);
      expect(sporran.lawnIsOpen, isTrue);
      sporran.online = true;
      
    });
    
    sporran = new Sporran(databaseName,
        hostName,
        port,
        scheme,
        userName,
        userPassword);
    
    
    sporran.onReady.listen((e) => wrapper());  
  
    });
    
    test("Wilt - Bulk Insert Supplied Keys", () {  
      
      var completer = expectAsync0((){
        
        JsonObject res = wilting.completionResponse;
        try {
          expect(res.error, isFalse);
        } catch(e) {
          
          logMessage("WILT::Bulk Insert Supplied Keys");
          JsonObject errorResponse = res.jsonCouchResponse;
          String errorText = errorResponse.error;
          logMessage("WILT::Error is $errorText");
          String reasonText = errorResponse.reason;
          logMessage("WILT::Reason is $reasonText");
          int statusCode = res.errorCode;
          logMessage("WILT::Status code is $statusCode");
          return;
        }
        
        JsonObject successResponse = res.jsonCouchResponse;
        expect(successResponse[0].id, equals("MyBulkId1"));
        expect(successResponse[1].id, equals("MyBulkId2")); 
        expect(successResponse[2].id, equals("MyBulkId3"));
        docId1Rev = successResponse[0].rev;
        docId2Rev = successResponse[1].rev;
        docId3Rev = successResponse[2].rev;
        
      });
      
      wilting.resultCompletion = completer;
      
      JsonObject document1 = new JsonObject();
      document1.title = "Document 1";
      document1.version = 1;
      document1.attribute = "Doc 1 attribute";
      String doc1 = WiltUserUtils.addDocumentId(document1, 
      "MyBulkId1");
      JsonObject document2 = new JsonObject();
      document2.title = "Document 2";
      document2.version = 2;
      document2.attribute = "Doc 2 attribute";
      String doc2 = WiltUserUtils.addDocumentId(document2,
      "MyBulkId2");
      JsonObject document3 = new JsonObject();
      document3.title = "Document 3";
      document3.version = 3;
      document3.attribute = "Doc 3 attribute";
      String doc3 = WiltUserUtils.addDocumentId(document3,
      "MyBulkId3");       
      List docList = new List<String>();
      docList.add(doc1);
      docList.add(doc2);
      docList.add(doc3);
      String docs = WiltUserUtils.createBulkInsertString(docList);
      wilting.bulkString(docs);    
      
    });  
    
    /* Pause a little for the notifications to come through */
    test("Notification Pause", () { 
      
      var wrapper = expectAsync0(() {
        
        
      });
      
      Timer pause = new Timer(new Duration(seconds:3), wrapper);
      
    });
    
    /* Go offline and get our created documents, from local storage */
    test("Get Document Offline MyBulkId1", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.GET); 
        expect(res.localResponse, isTrue);
        expect(res.id, "MyBulkId1");
        expect(res.payload.title, "Document 1");
        expect(res.payload.version,1);
        expect(res.payload.attribute, "Doc 1 attribute");
        
      });
      
      sporran.online = false;
      sporran.clientCompleter = wrapper;
      sporran.get("MyBulkId1");
    
    
  });
  
  test("Get Document Offline MyBulkId2", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.GET); 
        expect(res.localResponse, isTrue);
        expect(res.id, "MyBulkId2");
        expect(res.payload.title, "Document 2");
        expect(res.payload.version,2);
        expect(res.payload.attribute, "Doc 2 attribute");
        
      });
     
      sporran.clientCompleter = wrapper;
      sporran.get("MyBulkId2");
    
  });
  
  test("Get Document Offline MyBulkId3", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isTrue);
        expect(res.operation, Sporran.GET); 
        expect(res.localResponse, isTrue);
        expect(res.id, "MyBulkId3");
        expect(res.payload.title, "Document 3");
        expect(res.payload.version,3);
        expect(res.payload.attribute, "Doc 3 attribute");
        
      });
     
      sporran.clientCompleter = wrapper;
      sporran.get("MyBulkId3");
    
  });
  
  test("Wilt - Delete Document MyBulkId1", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = wilting.completionResponse;
        try {
          expect(res.error, isFalse);
        } catch(e) {
          
          logMessage("WILT::Delete Document MyBulkId1");
          JsonObject errorResponse = res.jsonCouchResponse;
          String errorText = errorResponse.error;
          logMessage("WILT::Error is $errorText");
          String reasonText = errorResponse.reason;
          logMessage("WILT::Reason is $reasonText");
          int statusCode = res.errorCode;
          logMessage("WILT::Status code is $statusCode");
          return;
        }
        
        JsonObject successResponse = res.jsonCouchResponse;
        expect(successResponse.id, "MyBulkId1");
        
      });
      
      wilting.resultCompletion = wrapper;
      wilting.deleteDocument("MyBulkId1", docId1Rev);
    
  });
  
  test("Wilt - Delete Document MyBulkId2", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = wilting.completionResponse;
        try {
          expect(res.error, isFalse);
        } catch(e) {
          
          logMessage("WILT::Delete Document MyBulkId2");
          JsonObject errorResponse = res.jsonCouchResponse;
          String errorText = errorResponse.error;
          logMessage("WILT::Error is $errorText");
          String reasonText = errorResponse.reason;
          logMessage("WILT::Reason is $reasonText");
          int statusCode = res.errorCode;
          logMessage("WILT::Status code is $statusCode");
          return;
        }
        
        JsonObject successResponse = res.jsonCouchResponse;
        expect(successResponse.id, "MyBulkId2");
        
      });
      
      wilting.resultCompletion = wrapper;
      wilting.deleteDocument("MyBulkId2", docId2Rev);
    
  });
  
  test("Wilt - Delete Document MyBulkId3", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = wilting.completionResponse;
        try {
          expect(res.error, isFalse);
        } catch(e) {
          
          logMessage("WILT::Delete Document MyBulkId3");
          JsonObject errorResponse = res.jsonCouchResponse;
          String errorText = errorResponse.error;
          logMessage("WILT::Error is $errorText");
          String reasonText = errorResponse.reason;
          logMessage("WILT::Reason is $reasonText");
          int statusCode = res.errorCode;
          logMessage("WILT::Status code is $statusCode");
          return;
        }
        
        JsonObject successResponse = res.jsonCouchResponse;
        expect(successResponse.id, "MyBulkId3");
        
      });
      
      wilting.resultCompletion = wrapper;
      wilting.deleteDocument("MyBulkId3", docId3Rev);
    
  });
  
    /* Pause a little for the notifications to come through */
    test("Notification Pause", () { 
      
      var wrapper = expectAsync0(() {
        
        
      });
      
      Timer pause = new Timer(new Duration(seconds:3), wrapper);
      
    });
    
    /* Go offline and get our created documents, from local storage */
    test("Get Document Offline Deleted MyBulkId1", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.GET); 
        expect(res.localResponse, isTrue);
        
      });
      
      sporran.online = false;
      sporran.clientCompleter = wrapper;
      sporran.get("MyBulkId1");
    
    
  });
  
  test("Get Document Offline Deleted MyBulkId2", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.GET); 
        expect(res.localResponse, isTrue);
        
      });
     
      sporran.clientCompleter = wrapper;
      sporran.get("MyBulkId2");
    
  });
  
  test("Get Document Offline Deleted MyBulkId3", () { 
      
      var wrapper = expectAsync0(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.ok, isFalse);
        expect(res.operation, Sporran.GET); 
        expect(res.localResponse, isTrue);
        
      });
     
      sporran.clientCompleter = wrapper;
      sporran.get("MyBulkId3");
    
  });
  
  
  
  });
  
}