import 'dart:html';
import 'dart:math';
//import 'dart:async';
import 'package:sporran/sporran.dart';
import 'package:json_object/json_object.dart';

Sporran sporran = null;
final String DB_NAME = "sporranlab001";

void main() {
  if (sporran == null) {
    SporranInitialiser initialiser = new SporranInitialiser();
    initialiser.dbName = DB_NAME;
    initialiser.hostname = 'localhost';
    initialiser.manualNotificationControl = false;
    initialiser.port = '8085';
    initialiser.scheme = 'http://';
    initialiser.username = 'steve';
    initialiser.password = 'wij7hwip';
    initialiser.preserveLocal = false;
    sporran = new Sporran(initialiser);
  }

  sporran.autoSync = true;
  sporran.onReady.first.then((e) => insertRecords());
}

void insertRecords() {
  Person person = new Person();
  person.id = generateId().toString();
  person.firstName = "Some Guy First Name " + person.id;
  person.lastName = "Last Name " + person.id;

  JsonObject jsonObject = new JsonObject();
  jsonObject.addAll(person.toMap());
  print("inserting Record " + person.id);
  sporran.put(person.id, jsonObject, null).catchError((e) => onError);
//Timer pause = new Timer(new Duration(seconds: 60),(){print("Times up");});
}

void onError(e) {
  window.alert('Oh no! Something went wrong. See the console for details.');
  window.console.log('An error occurred: {$e}');
}

int generateId() {
  var random = new Random();
  return random.nextInt(1 << 16);
}

class Person {
  String id;
  String firstName, lastName;
  Map toMap() => {
    "id": id,
    "firstName": firstName,
    "lastName": lastName
  };
  static Person fromMap(Map map) {
    Person person = new Person();
    person.id = map["id"];
    person.firstName = map["firstName"];
    person.lastName = map["lastName"];
    return person;
  }
}
