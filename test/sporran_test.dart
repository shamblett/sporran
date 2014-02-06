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
import 'package:json_object/json_object.dart' as jsonobject;
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
    
    
   
  });    
  
}