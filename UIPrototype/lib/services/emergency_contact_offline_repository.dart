import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/services.dart';
import '../models/base_response.dart';
import '../models/emergency_contact_model.dart';
import 'api_client.dart';
import 'emergency_service.dart';
import 'offline_operation_queue.dart';

class EmergencyContactOfflineRepository {
  EmergencyContactOfflineRepository({EmergencyService? remote}) : _remote = remote ?? EmergencyService();
  final EmergencyService _remote;
  static const _channel = MethodChannel('ankang_assistant/sos_device');
  final _random = Random();
  final StreamController<List<EmergencyContactModel>> _changes =
      StreamController<List<EmergencyContactModel>>.broadcast();

  Stream<List<EmergencyContactModel>> get changes => _changes.stream;

  Future<List<EmergencyContactModel>?> cached(int owner) async {
    return _queued(owner, () async {
      final state = await _load(owner);
      return state?.visible;
    });
  }
  Future<BaseResponse<List<EmergencyContactModel>>> get(int owner) async {
    final hasLocalState = await _queued(owner, () async {
      return await _load(owner) != null;
    });
    if (!hasLocalState) return _remote.getContacts();

    await sync(owner);
    try {
      final response = await _remote.getContacts();
      if (response.success && response.data != null) {
        return _queued(owner, () async {
          final latest = await _load(owner) ?? _State([]);
          latest.merge(response.data!);
          await _save(owner, latest);
          return BaseResponse(
            code: 200,
            message: 'success',
            success: true,
            data: latest.visible,
          );
        });
      }
    } catch (_) {}
    return _queued(owner, () async {
      final latest = await _load(owner) ?? _State([]);
      return BaseResponse(
        code: 200,
        message: 'success',
        success: true,
        data: latest.visible,
      );
    });
  }
  Future<void> sync(int owner) async {
    await _queuedSync(owner, () => _syncNow(owner));
  }
  Future<BaseResponse<EmergencyContactModel>> save(int owner, EmergencyContactModel draft) async {
    final result = await _queued(owner, () async {
      final state = await _load(owner);
      if (state == null) {
        return draft.id > 0
            ? _remote.updateContact(draft)
            : _remote.saveContact(draft);
      }
      final localDraft = _withLocalPhoneCapability(draft);
      final found =
          state.entries.where((entry) => entry.contact.id == draft.id).firstOrNull;
      final wasPrimary = found?.contact.priority == 1;
      final identity = found?.contact.clientContactId ?? _id();
      late final _Entry savedEntry;
      if (found == null) {
        final id = -DateTime.now().microsecondsSinceEpoch;
        savedEntry = _Entry(
          localDraft.copyWith(id: id, clientContactId: identity),
          dirty: true,
        );
        state.entries.add(savedEntry);
      } else {
        found.contact = localDraft.copyWith(
          clientContactId: identity,
          syncState: ContactSyncState.pending,
        );
        found.dirty = true;
        found.error = null;
        savedEntry = found;
      }
      state.normalize(
        preferredPrimary: localDraft.priority == 1 ? savedEntry : null,
        excludedPrimary:
            wasPrimary && localDraft.priority != 1 ? savedEntry : null,
      );
      await _save(owner, state);
      _changes.add(state.visible);
      final local = state.visible.firstWhere(
        (contact) => contact.clientContactId == identity,
      );
      return BaseResponse(
        code: 200,
        message: 'saved locally',
        success: true,
        data: local,
      );
    });
    unawaited(sync(owner));
    return result;
  }
  Future<BaseResponse<void>> delete(int owner, int id) async {
    final result = await _queued(owner, () async {
      final state = await _load(owner);
      if (state == null) {
        return _remote.deleteContact(id);
      }
      final entry =
          state.entries.where((item) => item.contact.id == id).firstOrNull;
      if (entry != null) {
        if (entry.serverId == null) {
          state.entries.remove(entry);
        } else {
          entry.deleted = true;
        }
        state.normalize();
        await _save(owner, state);
        _changes.add(state.visible);
      }
      return const BaseResponse(
        code: 200,
        message: 'saved locally',
        success: true,
      );
    });
    unawaited(sync(owner));
    return result;
  }
  Future<_State?> _load(int owner) async { try{final raw=await _channel.invokeMethod<String>('loadLocalContactState',{'ownerUserId':owner}); return raw==null?null:_State.fromJson(raw);}on MissingPluginException{return null;}on PlatformException{return null;} }
  Future<void> _save(int o,_State s)=>_channel.invokeMethod('saveLocalContactState',{'ownerUserId':o,'json':s.json});
  Future<void> _syncNow(int owner) async {
    while (true) {
      final entry = await _queued(owner, () async {
        final state = await _load(owner);
        return state?.entries
            .where(
              (item) =>
                  item.deleted || item.serverId == null || item.dirty,
            )
            .firstOrNull;
      });
      if (entry == null) return;
      try {
        if (entry.deleted) {
          if (entry.serverId != null) {
            try { final response = await _remote.deleteContact(entry.serverId!); if (!response.success) throw ApiException(response.message); }
            on ApiException catch (error) { if (error.statusCode != 404 && !error.message.contains('不存在')) rethrow; }
          }
          await _queued(owner, () async {
            final state = await _load(owner);
            final current = state == null ? null : _matchingEntry(state, entry);
            if (current != null && current.deleted) {
              state!.entries.remove(current);
              await _save(owner, state);
              _changes.add(state.visible);
            }
          });
        } else if (entry.serverId == null) {
          final desired = entry.contact;
          final response = await _remote.saveContact(
            _forRemote(desired).copyWith(id: 0),
          );
          if (!response.success || response.data == null) throw ApiException(response.message);
          final created = response.data!;
          var synced = created;
          if (!_sameContactContent(created, desired)) {
            final updateResponse = await _remote.updateContact(
              _forRemote(desired).copyWith(id: created.id),
            );
            if (!updateResponse.success || updateResponse.data == null) {
              throw ApiException(updateResponse.message);
            }
            synced = updateResponse.data!;
          }
          await _queued(owner, () async {
            final state = await _load(owner);
            final current = state == null ? null : _matchingEntry(state, entry);
            if (current == null) return;
            current.serverId = created.id;
            if (!current.deleted &&
                _sameContactContent(current.contact, desired)) {
              current.contact = synced.copyWith(
                clientContactId: current.contact.clientContactId,
              );
              current.dirty = false;
              current.error = null;
            }
            await _save(owner, state!);
            _changes.add(state.visible);
          });
        } else if (entry.dirty) {
          try {
            final response = await _remote.updateContact(
              _forRemote(entry.contact).copyWith(id: entry.serverId),
            );
            if (!response.success || response.data == null) throw ApiException(response.message);
            await _queued(owner, () async {
              final state = await _load(owner);
              final current =
                  state == null ? null : _matchingEntry(state, entry);
              if (current == null) return;
              if (!current.deleted &&
                  _sameContactContent(current.contact, entry.contact)) {
                current.contact = response.data!.copyWith(
                  clientContactId: current.contact.clientContactId,
                );
                current.dirty = false;
                current.error = null;
              }
              await _save(owner, state!);
              _changes.add(state.visible);
            });
          } on ApiException catch (error) {
            if (error.statusCode != 404 && !error.message.contains('不存在')) rethrow;
            await _queued(owner, () async {
              final state = await _load(owner);
              final current =
                  state == null ? null : _matchingEntry(state, entry);
              if (current == null) return;
              current.serverId = null;
              current.dirty = true;
              await _save(owner, state!);
            });
          }
        }
      } catch (error) {
        await _queued(owner, () async {
          final state = await _load(owner);
          final current = state == null ? null : _matchingEntry(state, entry);
          if (current != null) {
            current.error = '$error';
            await _save(owner, state!);
            _changes.add(state.visible);
          }
        });
        return;
      }
    }
  }
  String _id()=> 'c${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1<<20).toRadixString(36)}';
  EmergencyContactModel _forRemote(EmergencyContactModel contact) {
    return contact.copyWith(priority: contact.priority == 1 ? 1 : 0);
  }
  EmergencyContactModel _withLocalPhoneCapability(EmergencyContactModel contact) {
    final phone = contact.phone.trim();
    final mobile = RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);
    return contact.copyWith(
      phoneE164: mobile ? '+86$phone' : contact.phoneE164,
      phoneType: mobile ? 'mobile' : contact.phoneType,
      smsCapable: mobile,
    );
  }

  bool _sameContactContent(
    EmergencyContactModel left,
    EmergencyContactModel right,
  ) {
    return left.name == right.name &&
        left.phone == right.phone &&
        left.relationship == right.relationship &&
        (left.priority == 1) == (right.priority == 1);
  }

  _Entry? _matchingEntry(_State state, _Entry snapshot) {
    final clientContactId = snapshot.contact.clientContactId;
    return state.entries.where((entry) {
      if (clientContactId != null && clientContactId.isNotEmpty) {
        return entry.contact.clientContactId == clientContactId;
      }
      if (snapshot.serverId != null) {
        return entry.serverId == snapshot.serverId;
      }
      return entry.contact.id == snapshot.contact.id;
    }).firstOrNull;
  }

  Future<T> _queued<T>(
    int ownerUserId,
    Future<T> Function() operation,
  ) {
    return OfflineOperationQueue.run<T>(
      scope: 'emergency-contacts',
      ownerUserId: ownerUserId,
      operation: operation,
    );
  }

  Future<T> _queuedSync<T>(
    int ownerUserId,
    Future<T> Function() operation,
  ) {
    return OfflineOperationQueue.run<T>(
      scope: 'emergency-contacts-sync',
      ownerUserId: ownerUserId,
      operation: operation,
    );
  }
}
class _Entry { _Entry(this.contact,{this.serverId,this.dirty=false,this.deleted=false,this.error}); EmergencyContactModel contact;int? serverId;bool dirty,deleted;String? error; Map<String,dynamic> toJson()=>{'contact':contact.toJson(),'serverId':serverId,'dirty':dirty,'deleted':deleted,'error':error}; factory _Entry.fromJson(Map<String,dynamic> j)=>_Entry(EmergencyContactModel.fromJson(j['contact']),serverId:j['serverId'],dirty:j['dirty']??false,deleted:j['deleted']??false,error:j['error']); }
class _State {
  _State(this.entries);

  final List<_Entry> entries;

  List<EmergencyContactModel> get visible => entries
      .where((entry) => !entry.deleted)
      .map(
        (entry) => entry.contact.copyWith(
          syncState: entry.error != null
              ? ContactSyncState.failed
              : entry.dirty || entry.serverId == null
                  ? ContactSyncState.pending
                  : ContactSyncState.synced,
        ),
      )
      .toList();

  String get json =>
      jsonEncode({'entries': entries.map((entry) => entry.toJson()).toList()});

  factory _State.fromJson(String raw) {
    try {
      return _State(
        ((jsonDecode(raw)['entries'] as List?) ?? [])
            .map(
              (entry) =>
                  _Entry.fromJson(Map<String, dynamic>.from(entry)),
            )
            .toList(),
      );
    } catch (_) {
      return _State([]);
    }
  }

  void normalize({
    _Entry? preferredPrimary,
    _Entry? excludedPrimary,
  }) {
    final live = entries.where((entry) => !entry.deleted).toList();
    if (live.isEmpty) {
      return;
    }
    final candidates =
        live.where((entry) => !identical(entry, excludedPrimary)).toList();
    final primary = preferredPrimary != null && live.contains(preferredPrimary)
        ? preferredPrimary
        : candidates
                .where((entry) => entry.contact.priority == 1)
                .firstOrNull ??
            candidates.firstOrNull ??
            live.first;
    live
      ..remove(primary)
      ..insert(0, primary);
    for (var index = 0; index < live.length; index++) {
      live[index].contact = live[index].contact.copyWith(priority: index + 1);
    }
  }

  void merge(List<EmergencyContactModel> remote) {
    final ids = entries
        .where(
          (entry) =>
              entry.dirty || entry.deleted || entry.serverId == null,
        )
        .map((entry) => entry.serverId)
        .toSet();
    entries
      ..removeWhere(
        (entry) =>
            !entry.dirty && !entry.deleted && entry.serverId != null,
      )
      ..addAll(
        remote
            .where((contact) => !ids.contains(contact.id))
            .map((contact) => _Entry(contact, serverId: contact.id)),
      );
    normalize();
  }
}
extension<T> on Iterable<T>{T? get firstOrNull{final i=iterator;return i.moveNext()?i.current:null;}}
