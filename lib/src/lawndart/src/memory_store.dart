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

/// In memory store
class MemoryStore extends _MapStore {
  MemoryStore._() : super._();

  /// Open the store
  static Future<MemoryStore> open() async {
    final Store store = MemoryStore._();
    await store._open();
    return store as FutureOr<MemoryStore>;
  }

  @override
  Map<String, String> _generateMap() => <String, String>{};
}
