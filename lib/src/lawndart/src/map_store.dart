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

part of lawndart;

abstract class _MapStore extends Store {
  _MapStore._() : super._();
  late Map<String, String> storage;

  @override
  Future<bool> _open() async {
    storage = _generateMap();
    return true;
  }

  Map<String, String> _generateMap();

  @override
  Stream<String> keys() async* {
    for (final k in storage.keys) {
      yield k;
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
  Future<bool> exists(String key) async => storage.containsKey(key);

  @override
  Stream<String> all() async* {
    for (final v in storage.values) {
      yield v;
    }
  }

  @override
  Future<bool> removeByKey(String key) async {
    storage.remove(key);
    return true;
  }

  @override
  Future<bool> removeByKeys(Iterable<String> keys) async {
    keys.forEach(storage.remove);
    return true;
  }

  @override
  Future<bool> nuke() async {
    storage.clear();
    return true;
  }
}
