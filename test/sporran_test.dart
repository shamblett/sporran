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
import 'package:wilt/wilt.dart' show WiltUserUtils;
import 'package:json_object/json_object.dart';
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
    
    
    /* Wait for the database to open, only need to do this once.
     * In the real world there's no need to do this, only in harness
     * world.
     */
    Timer wait = new Timer(new Duration(milliseconds:300),wrapper);  
  
    });
    
  test("Put Document Online docIdPutOnline", () { 
      
     
      var wrapper = expectAsync0(() {
                    
          JsonObject res = sporran.completionResponse;
          expect(res.ok, isTrue);
          expect(res.operation, Sporran.PUT);         
        
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
      
       
     });
     
     sporran.online = true;
     sporran.clientCompleter = wrapper;
     onlineDoc.name = "Online";
     sporran.put(docIdPutOnline,onlineDoc);                                   
     
   });
   
   
   
   test("Get Document Offline docIdPutOnline", () { 
     
     var wrapper = expectAsync0(() {
       
       JsonObject res = sporran.completionResponse;
       expect(res.ok, isTrue);
       expect(res.operation, Sporran.GET);  
       expect(res.payload.name, "Online");
       
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
       expect(res.payload.name, "Offline");
       
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
       expect(res.payload.name, "Online");
       onlineDocRev = WiltUserUtils.getDocumentRev(res.payload);
       
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
        
      });
      
      sporran.online = false;;
      sporran.clientCompleter = wrapper;
      sporran.delete("Billy");
      
      
    }); 
     
     test("Delete Document Offline", () { 
       
       var wrapper = expectAsync0(() {
         
         JsonObject res = sporran.completionResponse;
         expect(res.ok, isTrue);
         expect(res.operation, Sporran.DELETE); 
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
         expect(res.operation, Sporran.DELETE); 
         expect(sporran.pendingDeleteSize, 1);
         
       });
       
       sporran.online = true;
       sporran.clientCompleter = wrapper;
       sporran.delete(docIdPutOnline,
                      onlineDocRev);
       
       
     });
    
  });
  
  /* Group 4 - Sporran attachment put/get tests */
  solo_group("4. Attachment Put/Get/Delete Tests - ", () {
    
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
      
    });
    
    sporran = new Sporran(databaseName,
        hostName,
        port,
        scheme,
        userName,
        userPassword);
    
    
    /* Wait for the database to open, only need to do this once */
    Timer wait = new Timer(new Duration(milliseconds:300),wrapper);
      
  
    });
    
  test("Put Document Online docIdPutOnline", () { 
      
     
      var wrapper = expectAsync0(() {
                    
          JsonObject res = sporran.completionResponse;
          expect(res.ok, isTrue);
          expect(res.operation, Sporran.PUT); 
          onlineDocRev = res.payload.rev;
        
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
      expect(res.operation, Sporran.PUT);  
      
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
        expect(res.operation, Sporran.PUT);  
        
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
  
  });
  
}