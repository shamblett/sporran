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
  group("2. Document Put/Get Tests - ", () {
    
    Sporran sporran = new Sporran(databaseName,
        hostName,
        port,
        scheme,
        userName,
        userPassword);
    
    String docIdPutOnline = "putOnline";
    String docIdPutOffline = "putOffline";
    JsonObject onlineDoc = new JsonObject();
    JsonObject offlineDoc = new JsonObject();
    
    solo_test("Put Document Online ", () { 
      
      var wrapper = expectAsync(() {
        
        JsonObject res = sporran.completionResponse;
        expect(res.error, isFalse);
        if ( !res.error ) {
          
          JsonObject successResponse = res.jsonCouchResponse;
          expect(successResponse.ok, isTrue);
          
        }
        
      });
      
      sporran.online = true;
      sporran.resultCompletion = wrapper;
      onlineDoc.name = "Online";
      /* Wait for the database to open, only need to do this once */
      Timer wait = new Timer(new Duration(milliseconds:500),
                             () => 
                               sporran.put(docIdPutOnline, 
                                           onlineDoc));
      
    });
    
  });
  
}