import 'dart:convert';
import 'dart:math';
import 'dart:async';

import '../models/base_response.dart';
import '../models/reminder_model.dart';
import 'api_client.dart';
import 'offline_operation_queue.dart';
import 'reminder_local_store_service.dart';
import 'reminder_notification_service.dart';
import 'reminder_service.dart';

class ReminderOfflineRepository {
  ReminderOfflineRepository({
    ReminderService? remote,
    ReminderLocalStoreService localStore = const ReminderLocalStoreService(),
    ReminderNotificationService notifications =
        const ReminderNotificationService(),
  })  : _remote = remote ?? ReminderService(),
        _localStore = localStore,
        _notifications = notifications;

  final ReminderService _remote;
  final ReminderLocalStoreService _localStore;
  final ReminderNotificationService _notifications;
  final Random _random = Random();

  Future<List<ReminderModel>?> getCachedReminders(int ownerUserId) async {
    return _queued(ownerUserId, () async {
      final state = await _loadState(ownerUserId);
      return state == null ? null : _visible(state);
    });
  }

  Future<BaseResponse<List<ReminderModel>>> getReminders(
      int ownerUserId) async {
    final hasLocalState = await _queued(ownerUserId, () async {
      return await _loadState(ownerUserId) != null;
    });
    if (!hasLocalState) return _remote.getReminders();

    await sync(ownerUserId);
    try {
      final response = await _remote.getReminders();
      if (response.success && response.data != null) {
        return _queued(ownerUserId, () async {
          final latest =
              await _loadState(ownerUserId) ?? _LocalReminderState();
          final merged = _mergeRemote(latest, response.data!);
          await _saveState(ownerUserId, merged);
          return _success(_visible(merged));
        });
      }
    } catch (_) {
      // Cached reminders remain usable while offline.
    }
    return _queued(ownerUserId, () async {
      final latest =
          await _loadState(ownerUserId) ?? _LocalReminderState();
      return _success(_visible(latest));
    });
  }

  Future<BaseResponse<ReminderModel>> create(
    int ownerUserId,
    ReminderModel draft,
  ) async {
    final result = await _queued(ownerUserId, () async {
      final state = await _loadState(ownerUserId);
      if (state == null) return _remote.saveReminder(draft);

      final clientId = _clientId(ownerUserId);
      final localId = -DateTime.now().microsecondsSinceEpoch;
      final reminder = draft.copyWith(
        id: localId,
        clientReminderId: clientId,
        syncState: ReminderSyncState.pending,
      );
      state.entries.add(
        _LocalReminderEntry(
          reminder: reminder,
          clientReminderId: clientId,
          contentDirty: true,
        ),
      );
      await _saveState(ownerUserId, state);
      await _notifications.schedule(
        ownerUserId: ownerUserId,
        reminder: reminder,
      );
      return _success(reminder);
    });
    unawaited(sync(ownerUserId));
    return result;
  }

  Future<BaseResponse<ReminderModel>> update(
    int ownerUserId,
    ReminderModel reminder,
  ) async {
    final result = await _queued(ownerUserId, () async {
      final state = await _loadState(ownerUserId);
      if (state == null) return _remote.updateReminder(reminder);

      final entry = _findEntry(state, reminder.id);
      if (entry == null) {
        state.entries.add(
          _LocalReminderEntry(
            reminder: reminder.copyWith(syncState: ReminderSyncState.pending),
            serverId: reminder.id > 0 ? reminder.id : null,
            clientReminderId:
                reminder.clientReminderId ?? _clientId(ownerUserId),
            contentDirty: true,
          ),
        );
      } else {
        entry
          ..reminder = reminder.copyWith(
            clientReminderId: entry.clientReminderId,
            syncState: ReminderSyncState.pending,
          )
          ..contentDirty = true
          ..syncError = null;
      }
      await _saveState(ownerUserId, state);
      await _notifications.schedule(
        ownerUserId: ownerUserId,
        reminder: reminder,
      );
      final local = _visible(state).firstWhere(
        (item) => item.id == reminder.id,
        orElse: () => reminder.copyWith(syncState: ReminderSyncState.pending),
      );
      return _success(local);
    });
    unawaited(sync(ownerUserId));
    return result;
  }

  Future<BaseResponse<void>> delete(int ownerUserId, int reminderId) async {
    final result = await _queued(ownerUserId, () async {
      final state = await _loadState(ownerUserId);
      if (state == null) return _remote.deleteReminder(reminderId);

      final entry = _findEntry(state, reminderId);
      if (entry != null) {
        if (entry.serverId == null) {
          state.entries.remove(entry);
        } else {
          entry
            ..deleted = true
            ..syncError = null;
        }
        await _saveState(ownerUserId, state);
      }
      await _notifications.cancel(
        ownerUserId: ownerUserId,
        reminderId: reminderId,
      );
      return const BaseResponse<void>(
        code: 200,
        message: 'saved locally',
        success: true,
      );
    });
    unawaited(sync(ownerUserId));
    return result;
  }

  Future<BaseResponse<void>> setCompleted(
    int ownerUserId,
    ReminderModel reminder,
    bool completed,
  ) async {
    final result = await _queued(ownerUserId, () async {
      final state = await _loadState(ownerUserId);
      if (state == null) {
        return completed
            ? _remote.completeReminder(reminder.id)
            : _remote.uncompleteReminder(reminder.id);
      }

      final entry = _findEntry(state, reminder.id);
      if (entry != null) {
        entry
          ..reminder = entry.reminder.copyWith(
            completed: completed,
            syncState: ReminderSyncState.pending,
          )
          ..completionDirty = true
          ..syncError = null;
        await _saveState(ownerUserId, state);
        await _notifications.schedule(
          ownerUserId: ownerUserId,
          reminder: entry.reminder,
        );
      }
      return const BaseResponse<void>(
        code: 200,
        message: 'saved locally',
        success: true,
      );
    });
    unawaited(sync(ownerUserId));
    return result;
  }

  Future<void> sync(int ownerUserId) async {
    await _queuedSync(ownerUserId, () => _syncNow(ownerUserId));
  }

  Future<_LocalReminderState?> _loadState(int ownerUserId) async {
    final raw = await _localStore.load(ownerUserId);
    if (raw == null) return null;
    if (raw.trim().isEmpty) return _LocalReminderState();
    try {
      return _LocalReminderState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return _LocalReminderState();
    }
  }

  Future<void> _saveState(
    int ownerUserId,
    _LocalReminderState state,
  ) async {
    await _localStore.save(ownerUserId, jsonEncode(state.toJson()));
  }

  Future<void> _syncNow(int ownerUserId) async {
    while (true) {
      final entry = await _queued(ownerUserId, () async {
        final state = await _loadState(ownerUserId);
        return state?.entries.where((item) => item.isDirty).firstOrNull;
      });
      if (entry == null) return;
      try {
        if (entry.deleted) {
          if (entry.serverId != null) {
            try {
              final response = await _remote.deleteReminder(entry.serverId!);
              if (!response.success) throw ApiException(response.message);
            } on ApiException catch (error) {
              if (error.statusCode != 404 &&
                  !error.message.contains('提醒不存在')) {
                rethrow;
              }
            }
          }
          await _queued(ownerUserId, () async {
            final state = await _loadState(ownerUserId);
            final current =
                state == null ? null : _matchingEntry(state, entry);
            if (current != null && current.deleted) {
              state!.entries.remove(current);
              await _saveState(ownerUserId, state);
            }
          });
        } else if (entry.serverId == null) {
          final oldId = entry.reminder.id;
          final desired = entry.reminder;
          final response = await _remote.saveReminder(
            desired.copyWith(
              id: 0,
              clientReminderId: entry.clientReminderId,
            ),
          );
          if (!response.success || response.data == null) {
            throw ApiException(response.message);
          }
          final created = response.data!;
          var synced = created;
          if (!_sameReminderContent(created, desired)) {
            final updateResponse = await _remote.updateReminder(
              desired.copyWith(id: created.id),
            );
            if (!updateResponse.success || updateResponse.data == null) {
              throw ApiException(updateResponse.message);
            }
            synced = updateResponse.data!;
          }
          await _queued(ownerUserId, () async {
            final state = await _loadState(ownerUserId);
            final current =
                state == null ? null : _matchingEntry(state, entry);
            if (current == null) return;
            current.serverId = created.id;
            current.reminder = current.reminder.copyWith(id: created.id);
            if (!current.deleted &&
                _sameReminderContent(current.reminder, desired)) {
              current.reminder = synced.copyWith(
                completed: current.reminder.completed,
                clientReminderId: current.clientReminderId,
              );
              current.contentDirty = false;
              current.syncError = null;
            }
            await _saveState(ownerUserId, state!);
            await _notifications.cancel(
              ownerUserId: ownerUserId,
              reminderId: oldId,
            );
            await _notifications.schedule(
              ownerUserId: ownerUserId,
              reminder: current.reminder,
            );
          });
        } else if (entry.contentDirty) {
          try {
            final response = await _remote.updateReminder(
              entry.reminder.copyWith(id: entry.serverId),
            );
            if (!response.success || response.data == null) {
              throw ApiException(response.message);
            }
            await _queued(ownerUserId, () async {
              final state = await _loadState(ownerUserId);
              final current =
                  state == null ? null : _matchingEntry(state, entry);
              if (current == null) return;
              if (!current.deleted &&
                  _sameReminderContent(current.reminder, entry.reminder)) {
                current.reminder = response.data!.copyWith(
                  completed: current.reminder.completed,
                  clientReminderId: current.clientReminderId,
                );
                current.contentDirty = false;
                current.syncError = null;
              }
              await _saveState(ownerUserId, state!);
            });
          } on ApiException catch (error) {
            if (error.statusCode != 404 && !error.message.contains('提醒不存在')) {
              rethrow;
            }
            await _queued(ownerUserId, () async {
              final state = await _loadState(ownerUserId);
              final current =
                  state == null ? null : _matchingEntry(state, entry);
              if (current == null) return;
              current.serverId = null;
              current.contentDirty = true;
              await _saveState(ownerUserId, state!);
            });
          }
        } else if (entry.completionDirty && entry.serverId != null) {
          final response = entry.reminder.completed
              ? await _remote.completeReminder(entry.serverId!)
              : await _remote.uncompleteReminder(entry.serverId!);
          if (!response.success) throw ApiException(response.message);
          await _queued(ownerUserId, () async {
            final state = await _loadState(ownerUserId);
            final current =
                state == null ? null : _matchingEntry(state, entry);
            if (current == null) return;
            if (current.reminder.completed == entry.reminder.completed) {
              current.completionDirty = false;
              current.syncError = null;
            }
            await _saveState(ownerUserId, state!);
          });
        } else {
          await _queued(ownerUserId, () async {
            final state = await _loadState(ownerUserId);
            final current =
                state == null ? null : _matchingEntry(state, entry);
            if (current != null) {
              current.syncError = null;
              await _saveState(ownerUserId, state!);
            }
          });
        }
      } catch (error) {
        await _queued(ownerUserId, () async {
          final state = await _loadState(ownerUserId);
          final current =
              state == null ? null : _matchingEntry(state, entry);
          if (current != null) {
            current.syncError = error.toString();
            await _saveState(ownerUserId, state!);
          }
        });
        return;
      }
    }
  }

  _LocalReminderState _mergeRemote(
    _LocalReminderState local,
    List<ReminderModel> remote,
  ) {
    final pending = local.entries.where((entry) => entry.isDirty).toList();
    final pendingServerIds =
        pending.map((entry) => entry.serverId).whereType<int>().toSet();
    final merged = <_LocalReminderEntry>[
      ...pending,
      for (final reminder in remote)
        if (!pendingServerIds.contains(reminder.id))
          _LocalReminderEntry(
            reminder: reminder,
            serverId: reminder.id,
            clientReminderId:
                reminder.clientReminderId ?? _clientId(reminder.id),
          ),
    ];
    return _LocalReminderState(entries: merged);
  }

  List<ReminderModel> _visible(_LocalReminderState state) {
    return state.entries
        .where((entry) => !entry.deleted)
        .map(
          (entry) => entry.reminder.copyWith(
            syncState: entry.syncError != null
                ? ReminderSyncState.failed
                : entry.isDirty
                    ? ReminderSyncState.pending
                    : ReminderSyncState.synced,
          ),
        )
        .toList();
  }

  _LocalReminderEntry? _findEntry(_LocalReminderState state, int id) {
    for (final entry in state.entries) {
      if (entry.reminder.id == id || entry.serverId == id) return entry;
    }
    return null;
  }

  _LocalReminderEntry? _matchingEntry(
    _LocalReminderState state,
    _LocalReminderEntry snapshot,
  ) {
    return state.entries
        .where(
          (entry) => entry.clientReminderId == snapshot.clientReminderId,
        )
        .firstOrNull;
  }

  bool _sameReminderContent(ReminderModel left, ReminderModel right) {
    return left.title == right.title &&
        left.type == right.type &&
        left.remindAt == right.remindAt &&
        left.repeatType == right.repeatType &&
        left.enabled == right.enabled &&
        left.remark == right.remark;
  }

  BaseResponse<T> _success<T>(T data) => BaseResponse<T>(
        code: 200,
        message: 'success',
        success: true,
        data: data,
      );

  Future<T> _queued<T>(
    int ownerUserId,
    Future<T> Function() operation,
  ) {
    return OfflineOperationQueue.run<T>(
      scope: 'reminders',
      ownerUserId: ownerUserId,
      operation: operation,
    );
  }

  Future<T> _queuedSync<T>(
    int ownerUserId,
    Future<T> Function() operation,
  ) {
    return OfflineOperationQueue.run<T>(
      scope: 'reminders-sync',
      ownerUserId: ownerUserId,
      operation: operation,
    );
  }

  String _clientId(int seed) {
    final micros = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = _random.nextInt(0x7fffffff).toRadixString(36);
    final owner = seed.abs().toRadixString(36);
    return 'r$micros$random$owner';
  }
}

class _LocalReminderState {
  _LocalReminderState({List<_LocalReminderEntry>? entries})
      : entries = entries ?? [];

  final List<_LocalReminderEntry> entries;

  factory _LocalReminderState.fromJson(Map<String, dynamic> json) {
    return _LocalReminderState(
      entries: ((json['entries'] as List<dynamic>?) ?? [])
          .map(
            (item) => _LocalReminderEntry.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      };
}

class _LocalReminderEntry {
  _LocalReminderEntry({
    required this.reminder,
    required this.clientReminderId,
    this.serverId,
    this.contentDirty = false,
    this.completionDirty = false,
    this.deleted = false,
    this.syncError,
  });

  ReminderModel reminder;
  int? serverId;
  final String clientReminderId;
  bool contentDirty;
  bool completionDirty;
  bool deleted;
  String? syncError;

  bool get isDirty =>
      serverId == null ||
      contentDirty ||
      completionDirty ||
      deleted ||
      syncError != null;

  factory _LocalReminderEntry.fromJson(Map<String, dynamic> json) {
    final reminderJson =
        Map<String, dynamic>.from(json['reminder'] as Map? ?? const {});
    reminderJson['completed'] = json['completed'] as bool? ?? false;
    return _LocalReminderEntry(
      reminder: ReminderModel.fromJson(reminderJson),
      serverId: json['serverId'] as int?,
      clientReminderId: json['clientReminderId'] as String? ?? '',
      contentDirty: json['contentDirty'] as bool? ?? false,
      completionDirty: json['completionDirty'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
      syncError: json['syncError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'reminder': reminder.toJson(),
        'completed': reminder.completed,
        'serverId': serverId,
        'clientReminderId': clientReminderId,
        'contentDirty': contentDirty,
        'completionDirty': completionDirty,
        'deleted': deleted,
        'syncError': syncError,
      };
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
