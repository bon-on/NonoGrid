import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// Minimal localStorage-like key/value API (CrazyGames SDK Data module, or
/// the browser's localStorage for bookkeeping).
abstract class CloudData {
  String? getItem(String key);
  void setItem(String key, String value);
}

/// Revision and owner of a preferences snapshot.
@immutable
class SnapshotStamp {
  const SnapshotStamp({required this.revision, required this.owner});

  /// Increases on every write; newer snapshots win for the same owner.
  final int revision;

  /// CrazyGames username, or null for a guest.
  final String? owner;
}

/// [SharedPreferencesStorePlatform] that keeps every preference in one JSON
/// item of the CrazyGames Data module, so logged-in players keep their
/// progress across devices. Every write is mirrored to the local store so
/// the browser copy survives if the Data module is later disabled, and a
/// local stamp records which player and revision that mirror belongs to.
class CloudPrefsStore extends SharedPreferencesStorePlatform {
  CloudPrefsStore._(
    this._cloud,
    this._local,
    this._localStamp,
    this._owner,
    this._revision,
    this._values,
  );

  /// Data module key that holds all preferences.
  static const String cloudKey = 'prefs_v1';

  /// Browser localStorage key holding the mirror's [SnapshotStamp]. It sits
  /// outside the `flutter.` prefix so it never shows up as a preference.
  static const String localStampKey = 'cg_prefs_stamp_v1';

  final CloudData _cloud;
  final SharedPreferencesStorePlatform _local;
  final CloudData _localStamp;
  final String? _owner;
  int _revision;
  final Map<String, Object> _values;

  /// Picks the snapshot to start from:
  /// - the local mirror when it belongs to [owner] (or predates this feature
  ///   and has no stamp while the cloud is empty) and is not older than the
  ///   cloud copy, which covers cloud saves lost to the SDK's debounce;
  /// - otherwise the cloud copy;
  /// - otherwise empty, so one player's mirror never leaks to another.
  /// Throws if the Data module itself fails, so callers keep [local].
  static Future<CloudPrefsStore> load({
    required CloudData cloud,
    required SharedPreferencesStorePlatform local,
    required CloudData localStamp,
    required String? owner,
  }) async {
    final remote = decodeEnvelope(cloud.getItem(cloudKey));
    final stamp = decodeStamp(localStamp.getItem(localStampKey));
    final localValues = Map<String, Object>.of(await local.getAll());

    final localIsOwners = stamp == null ? remote == null : stamp.owner == owner;
    final Map<String, Object> values;
    final int revision;
    if (localIsOwners &&
        (remote == null || (stamp?.revision ?? 0) >= remote.stamp.revision)) {
      values = localValues;
      revision = stamp?.revision ?? 0;
    } else {
      values = remote?.values ?? <String, Object>{};
      revision = remote?.stamp.revision ?? 0;
      // The mirror holds another snapshot: replace it before stamping it as
      // this player's, or its leftover keys would win on the next load.
      await _replaceMirror(local, values);
      try {
        localStamp.setItem(
          localStampKey,
          jsonEncode(<String, Object?>{'rev': revision, 'owner': owner}),
        );
      } catch (error) {
        // An old stamp only makes the next load redo this replacement.
        debugPrint('Local save stamp failed: $error');
      }
    }
    return CloudPrefsStore._(cloud, local, localStamp, owner, revision, values);
  }

  static Future<void> _replaceMirror(
    SharedPreferencesStorePlatform local,
    Map<String, Object> values,
  ) async {
    await local.clear();
    for (final entry in values.entries) {
      final value = entry.value;
      final type = switch (value) {
        bool() => 'Bool',
        int() => 'Int',
        double() => 'Double',
        String() => 'String',
        _ => 'StringList',
      };
      await local.setValue(type, entry.key, value);
    }
  }

  /// Decodes a cloud snapshot; null when missing or malformed. A bare map
  /// (no envelope) is read as revision 0 with an unknown owner.
  @visibleForTesting
  static ({SnapshotStamp stamp, Map<String, Object> values})? decodeEnvelope(
    String? raw,
  ) {
    final decoded = _decodeJson(raw);
    if (decoded is! Map) return null;
    final values = decoded['values'];
    if (values is Map) {
      final revision = decoded['rev'];
      final owner = decoded['owner'];
      return (
        stamp: SnapshotStamp(
          revision: revision is int ? revision : 0,
          owner: owner is String ? owner : null,
        ),
        values: decodeValues(values),
      );
    }
    return (
      stamp: const SnapshotStamp(revision: 0, owner: null),
      values: decodeValues(decoded),
    );
  }

  /// Keeps only value types shared_preferences supports.
  @visibleForTesting
  static Map<String, Object> decodeValues(Map<dynamic, dynamic> raw) {
    final values = <String, Object>{};
    raw.forEach((key, value) {
      if (key is! String) return;
      if (value is bool || value is num || value is String) {
        values[key] = value as Object;
      } else if (value is List && value.every((item) => item is String)) {
        values[key] = value.cast<String>().toList();
      }
    });
    return values;
  }

  @visibleForTesting
  static SnapshotStamp? decodeStamp(String? raw) {
    final decoded = _decodeJson(raw);
    if (decoded is! Map) return null;
    final revision = decoded['rev'];
    final owner = decoded['owner'];
    if (revision is! int) return null;
    return SnapshotStamp(
      revision: revision,
      owner: owner is String ? owner : null,
    );
  }

  static Object? _decodeJson(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  void _flush() {
    _revision++;
    final stamp = <String, Object?>{'rev': _revision, 'owner': _owner};
    try {
      _localStamp.setItem(localStampKey, jsonEncode(stamp));
    } catch (error) {
      debugPrint('Local save stamp failed: $error');
    }
    try {
      _cloud.setItem(
        cloudKey,
        jsonEncode(<String, Object?>{...stamp, 'values': _values}),
      );
    } catch (error) {
      debugPrint('CrazyGames data save failed: $error');
    }
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    _values[key] = value is List
        ? List<String>.of(value.cast<String>())
        : value;
    _flush();
    return _local.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    _flush();
    return _local.remove(key);
  }

  @override
  Future<bool> clear() async {
    _values.clear();
    _flush();
    return _local.clear();
  }

  @override
  Future<bool> clearWithPrefix(String prefix) => clearWithParameters(
    ClearParameters(filter: PreferencesFilter(prefix: prefix)),
  );

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) async {
    final filter = parameters.filter;
    _values.removeWhere((key, _) => _matches(key, filter));
    _flush();
    return _local.clearWithParameters(parameters);
  }

  @override
  Future<Map<String, Object>> getAll() async => Map<String, Object>.of(_values);

  @override
  Future<Map<String, Object>> getAllWithPrefix(String prefix) =>
      getAllWithParameters(
        GetAllParameters(filter: PreferencesFilter(prefix: prefix)),
      );

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) async {
    final filter = parameters.filter;
    return <String, Object>{
      for (final entry in _values.entries)
        if (_matches(entry.key, filter)) entry.key: entry.value,
    };
  }

  static bool _matches(String key, PreferencesFilter filter) =>
      key.startsWith(filter.prefix) &&
      (filter.allowList == null || filter.allowList!.contains(key));
}
