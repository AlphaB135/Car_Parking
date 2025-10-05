import 'dart:async';

/// Simple in-memory FakeDatabase that mimics a small subset of
/// Firebase Realtime Database API used by this app.
class FakeDatabaseReference {
  final String path;
  FakeDatabaseReference([this.path = '/']);

  // shared storage across references
  static final Map<String, dynamic> _store = <String, dynamic>{};

  // per-path controllers
  static final Map<String, StreamController<FakeDatabaseEvent>> _controllers =
      {};

  FakeDatabaseReference child(String name) =>
      FakeDatabaseReference(_join(path, name));

  Future<void> set(Object? value) async {
    _store[path] = value;
    _emit(path, FakeDatabaseEvent(value));
    return;
  }

  Future<void> update(Object? value) async {
    final existing = _store[path];
    if (existing is Map && value is Map) {
      _store[path] = {...existing, ...value};
    } else {
      _store[path] = value;
    }
    _emit(path, FakeDatabaseEvent(_store[path]));
    return;
  }

  /// Return the current value at this reference (synchronous snapshot-like)
  Future<dynamic> get() async {
    return _store[path];
  }

  Stream<FakeDatabaseEvent> get onValue {
    final controller = _controllers.putIfAbsent(
      path,
      () => StreamController<FakeDatabaseEvent>.broadcast(),
    );
    // emit current value immediately
    Future.microtask(() => controller.add(FakeDatabaseEvent(_store[path])));
    return controller.stream;
  }

  static void _emit(String path, FakeDatabaseEvent event) {
    final ctrl = _controllers[path];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(event);
  }

  static String _join(String base, String name) {
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (name.startsWith('/')) name = name.substring(1);
    return '$base/$name';
  }
}

class FakeDatabaseEvent {
  final dynamic snapshotValue;
  FakeDatabaseEvent(this.snapshotValue);
}
