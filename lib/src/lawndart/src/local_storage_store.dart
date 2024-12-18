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

/// Wraps the local storage API and exposes it as a [Store].
/// Local storage is a synchronous API, and generally not recommended
/// unless all other storage mechanisms are unavailable.
class LocalStorageStore extends _MapStore {
  LocalStorageStore._() : super._();

  /// Open the local storage
  static Future<LocalStorageStore> open() async {
    final Store store = LocalStorageStore._();
    await store._open();
    return store as FutureOr<LocalStorageStore>;
  }

  @override
  Storage _generateMap() => window.localStorage;
}
