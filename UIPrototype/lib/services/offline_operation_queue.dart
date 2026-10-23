import 'dart:async';

/// Serializes local-state mutations and remote reconciliation across repository
/// instances that operate on the same user-owned offline data.
class OfflineOperationQueue {
  OfflineOperationQueue._();

  static final Map<String, Future<void>> _tails = <String, Future<void>>{};

  static Future<T> run<T>({
    required String scope,
    required int ownerUserId,
    required Future<T> Function() operation,
  }) {
    final key = '$scope:$ownerUserId';
    final previous = _tails[key] ?? Future<void>.value();
    final result = Completer<T>();

    final next = previous.then((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });

    late final Future<void> tracked;
    tracked = next.whenComplete(() {
      if (identical(_tails[key], tracked)) {
        _tails.remove(key);
      }
    });
    _tails[key] = tracked;
    return result.future;
  }
}
