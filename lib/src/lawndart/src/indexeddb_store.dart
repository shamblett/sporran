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

/// Wraps the IndexedDB API and exposes it as a [Store].
/// IndexedDB is generally the preferred API if it is available.
class IndexedDbStore extends Store {
  /// Database name
  final String dbName;

  /// Store name
  final String storeName;

  static final Map<String, idb.Database> _databases = <String, idb.Database>{};

  /// Returns true if IndexedDB is supported on this platform.
  static bool get supported => idb.IdbFactory.supported;

  idb.Database? get _db => _databases[dbName];

  /// Construction
  IndexedDbStore._(this.dbName, this.storeName) : super._();

  /// Open
  static Future<IndexedDbStore> open(String dbName, String storeName) async {
    final store = IndexedDbStore._(dbName, storeName);
    await store._open();
    return store;
  }

  @override
  Future<void> removeByKey(String key) =>
      _runInTxn((dynamic store) => store.delete(key));

  @override
  Future<String> save(String obj, String key) =>
      _runInTxn<String>((dynamic store) async => await store.put(obj, key));

  @override
  Future<dynamic> getByKey(String key) => _runInTxn<dynamic>(
    (dynamic store) async => await store.getObject(key),
    'readonly',
  );

  @override
  Future<void> nuke() => _runInTxn((dynamic store) => store.clear());

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
      return null;
    });
  }

  @override
  Stream<String> getByKeys(Iterable<String> keys) async* {
    for (final key in keys) {
      final v = await getByKey(key);
      if (v != null) {
        if (v.isNotEmpty) {
          yield v as String;
        }
      }
    }
  }

  @override
  Future<bool> removeByKeys(Iterable<String> keys) {
    // ignore: missing_return
    return _runInTxn((dynamic store) {
      keys.forEach(store.delete);
      return null;
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

  @override
  Future<void> _open() async {
    final factory = idb.IdbFactory();
    if (!supported) {
      throw UnsupportedError('IndexedDB is not supported on this platform');
    }

    void upgradeNeeded(idb.VersionChangeEvent event) async {
      final db = event.target.database;
      if (db.objectStoreNames != null) {
        if (!db.objectStoreNames!.contains(storeName)) {
          db.createObjectStore(storeName);
        }
      } else {
        db.createObjectStore(storeName);
      }
    }

    final db = await factory.open(
      dbName,
      version: 1,
      onUpgradeNeeded: upgradeNeeded,
    );
    _databases[dbName] = db;
  }

  Future<T> _runInTxn<T>(
    Future<T>? Function(idb.ObjectStore) requestCommand, [
    String txnMode = 'readwrite',
  ]) async {
    final trans = _db!.transaction(storeName, txnMode);
    final store = trans.objectStore(storeName);
    final result = await requestCommand(store)!;
    await trans.completed;
    return result;
  }

  Stream<String> _doGetAll(
    String? Function(idb.CursorWithValue?) onCursor,
  ) async* {
    final trans = _db!.transaction(storeName, 'readonly');
    final store = trans.objectStore(storeName);
    await for (final dynamic cursor in store.openCursor(autoAdvance: true)) {
      yield onCursor(cursor)!;
    }
  }
}
