//Copyright 2012 Google
//
//Licensed under the Apache License, Version 2.0 (the "License");
//you may not use this file except in compliance with the License.
//You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//Unless required by applicable law or agreed to in writing, software
//distributed under the License is distributed on an "AS IS" BASIS,
//WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//See the License for the specific language governing permissions and
//limitations under the License.

part of '../lawndart.dart';

abstract class _MapStore extends Store {
  _MapStore._() : super._();
  late Storage storage;

  @override
  Future<bool> _open() async {
    storage = _generateMap();
    return true;
  }

  Storage _generateMap();

  @override
  Stream<String?> keys() async* {
    for (int k = 0; k < storage.length; k++) {
      yield storage.key(k);
    }
  }

  @override
  Future<String> save(String obj, String key) async {
    storage[key] = obj;
    return key;
  }

  @override
  Future<void> batch(Map<String, String> objectsByKey) async {
    for (final key in objectsByKey.keys) {
      storage[key] = objectsByKey[key]!;
    }
  }

  @override
  Future<String> getByKey(String key) async => storage[key]!;

  @override
  Stream<String> getByKeys(Iterable<String> keys) async* {
    final values =
        keys.map((String key) => storage[key]).where((final v) => v != null);
    for (final v in values) {
      yield v!;
    }
  }

  @override
  Future<bool> exists(String key) async => storage.getItem(key) != null;

  @override
  Stream<String?> all() async* {
    for (int k = 0; k < storage.length; k++) {
      yield storage.getItem(storage.key(k)!);
    }
  }

  @override
  Future<bool> removeByKey(String key) async {
    storage.removeItem(key);
    return true;
  }

  @override
  Future<bool> removeByKeys(Iterable<String> keys) async {
    for (final key in keys) {
      storage.removeItem(key);
    }

    return true;
  }

  @override
  Future<bool> nuke() async {
    storage.clear();
    return true;
  }
}
