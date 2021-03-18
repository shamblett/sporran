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

/// Wraps the IndexedDB API and exposes it as a [Store].
/// IndexedDB is generally the preferred API if it is available.
class IndexedDbStore extends Store {
  /// Construction
  IndexedDbStore._(this.dbName, this.storeName) : super._();

  static final Map<String, idb.Database> _databases = <String, idb.Database>{};

  /// Database name
  final dbName;

  /// Store name
  final storeName;

  /// Open
  static Future<IndexedDbStore> open(String dbName, String storeName) async {
    final store = IndexedDbStore._(dbName, storeName);
    await store._open();
    return store;
  }

  /// Returns true if IndexedDB is supported on this platform.
  static bool get supported => idb.IdbFactory.supported;

  @override
  Future<void> _open() async {
    if (!supported) {
      throw UnsupportedError('IndexedDB is not supported on this platform');
    }

    if (_db != null) {
      _db!.close();
    }

    var db = await window.indexedDB!.open(dbName!);

    if (!db.objectStoreNames!.contains(storeName)) {
      db.close();
      //print('Attempting upgrading $storeName from ${db.version}');
      db = await window.indexedDB!.open(dbName!, version: db.version! + 1,
          onUpgradeNeeded: (dynamic e) {
        final idb.Database d = e.target.result;
        d.createObjectStore(storeName);
      });
    }

    _databases[dbName] = db;
  }

  idb.Database? get _db => _databases[dbName];

  @override
  Future<void> removeByKey(String key) =>
      _runInTxn((dynamic store) => store.delete(key));

  @override
  Future<String> save(String obj, String key) =>
      _runInTxn<String>((dynamic store) async => await store.put(obj, key));

  @override
  Future<String> getByKey(String key) => _runInTxn<String>(
      (dynamic store) async => await store.getObject(key), 'readonly');

  @override
  Future<void> nuke() => _runInTxn((dynamic store) => store.clear());

  Future<T> _runInTxn<T>(Future<T>? Function(idb.ObjectStore) requestCommand,
      [String txnMode = 'readwrite']) async {
    final trans = _db!.transaction(storeName, txnMode);
    final store = trans.objectStore(storeName);
    final result = await requestCommand(store)!;
    await trans.completed;
    return result;
  }

  Stream<String> _doGetAll(
      String? Function(idb.CursorWithValue?) onCursor) async* {
    final trans = _db!.transaction(storeName, 'readonly');
    final store = trans.objectStore(storeName);
    await for (final dynamic cursor in store.openCursor(autoAdvance: true)) {
      yield onCursor(cursor)!;
    }
  }

  @override
  Stream<String> all() =>
      _doGetAll((idb.CursorWithValue? cursor) => cursor!.value);

  @override
  Future<void> batch(Map<String, String> objectsByKey) {
    // ignore: missing_return
    return _runInTxn((dynamic store) {
      objectsByKey.forEach((dynamic k, dynamic v) {
        store.put(v, k);
      });
    });
  }

  @override
  Stream<String> getByKeys(Iterable<String> keys) async* {
    for (final key in keys) {
      final v = await getByKey(key);
      if (v.isNotEmpty) {
        yield v;
      }
    }
  }

  @override
  Future<bool> removeByKeys(Iterable<String> keys) {
    // ignore: missing_return
    return _runInTxn((dynamic store) {
      keys.forEach(store.delete);
    });
  }

  @override
  Future<bool> exists(String key) async {
    final dynamic value = await getByKey(key);
    return value != null;
  }

  @override
  Stream<String> keys() =>
      _doGetAll((idb.CursorWithValue? cursor) => cursor!.key as String?);
}
