import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nono_grid/src/meta/daily.dart';
import 'package:nono_grid/src/platform/crazygames_prefs_store.dart';
import 'package:nono_grid/src/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

class _FakeData implements CloudData {
  _FakeData([Map<String, String>? items]) : items = items ?? <String, String>{};

  final Map<String, String> items;
  bool failReads = false;
  bool failWrites = false;

  @override
  String? getItem(String key) {
    if (failReads) throw StateError('dataModuleDisabled');
    return items[key];
  }

  @override
  void setItem(String key, String value) {
    if (failWrites) throw StateError('dataLimitExceeded');
    items[key] = value;
  }

  Map<String, dynamic> get envelope =>
      jsonDecode(items[CloudPrefsStore.cloudKey]!) as Map<String, dynamic>;

  Map<String, dynamic> get stamp =>
      jsonDecode(items[CloudPrefsStore.localStampKey]!) as Map<String, dynamic>;
}

String _envelope(int rev, String? owner, Map<String, Object> values) =>
    jsonEncode(<String, Object?>{'rev': rev, 'owner': owner, 'values': values});

String _stamp(int rev, String? owner) =>
    jsonEncode(<String, Object?>{'rev': rev, 'owner': owner});

InMemorySharedPreferencesStore _local(Map<String, Object> values) =>
    InMemorySharedPreferencesStore.withData(values);

Future<CloudPrefsStore> _load({
  required _FakeData cloud,
  Map<String, Object> local = const <String, Object>{},
  _FakeData? stamp,
  String? owner,
  InMemorySharedPreferencesStore? localStore,
}) => CloudPrefsStore.load(
  cloud: cloud,
  local: localStore ?? _local(local),
  localStamp: stamp ?? _FakeData(),
  owner: owner,
);

void main() {
  setUp(SharedPreferences.resetStatic);

  test('first run starts from unstamped local values and uploads', () async {
    final cloud = _FakeData();
    final stamp = _FakeData();
    final local = _local(<String, Object>{'flutter.best': 120});
    SharedPreferencesStorePlatform.instance = await _load(
      cloud: cloud,
      localStore: local,
      stamp: stamp,
      owner: 'ana',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('best'), 120);

    await prefs.setBool('muted', true);
    expect(cloud.envelope, <String, dynamic>{
      'rev': 1,
      'owner': 'ana',
      'values': <String, dynamic>{'flutter.best': 120, 'flutter.muted': true},
    });
    expect(stamp.stamp, <String, dynamic>{'rev': 1, 'owner': 'ana'});
    expect((await local.getAll())['flutter.muted'], isTrue);
  });

  test('newer cloud snapshot wins and every value type survives', () async {
    final cloud = _FakeData(<String, String>{
      CloudPrefsStore.cloudKey: _envelope(5, 'ana', <String, Object>{
        'flutter.best': 900,
        'flutter.progress': '{"xp":40}',
        'flutter.list': <String>['a', 'b'],
        'flutter.ratio': 1.5,
      }),
    });
    SharedPreferencesStorePlatform.instance = await _load(
      cloud: cloud,
      local: <String, Object>{'flutter.best': 5, 'flutter.other': 'x'},
      stamp: _FakeData(<String, String>{
        CloudPrefsStore.localStampKey: _stamp(3, 'ana'),
      }),
      owner: 'ana',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('best'), 900);
    expect(prefs.getString('progress'), '{"xp":40}');
    expect(prefs.getStringList('list'), <String>['a', 'b']);
    expect(prefs.getDouble('ratio'), 1.5);
    expect(prefs.getString('other'), isNull);
  });

  test('a newer local mirror of the same player beats a stale cloud', () async {
    final store = await _load(
      cloud: _FakeData(<String, String>{
        CloudPrefsStore.cloudKey: _envelope(4, 'ana', <String, Object>{
          'flutter.best': 10,
        }),
      }),
      local: <String, Object>{'flutter.best': 30},
      stamp: _FakeData(<String, String>{
        CloudPrefsStore.localStampKey: _stamp(6, 'ana'),
      }),
      owner: 'ana',
    );
    expect(await store.getAll(), <String, Object>{'flutter.best': 30});
  });

  test('another player\'s local mirror is never used', () async {
    // Logged out after playing as ana: the guest starts fresh.
    final guest = await _load(
      cloud: _FakeData(),
      local: <String, Object>{'flutter.best': 30},
      stamp: _FakeData(<String, String>{
        CloudPrefsStore.localStampKey: _stamp(6, 'ana'),
      }),
    );
    expect(await guest.getAll(), isEmpty);

    // Bob logs in on ana's browser: bob's cloud copy wins.
    final bob = await _load(
      cloud: _FakeData(<String, String>{
        CloudPrefsStore.cloudKey: _envelope(1, 'bob', <String, Object>{
          'flutter.best': 2,
        }),
      }),
      local: <String, Object>{'flutter.best': 30},
      stamp: _FakeData(<String, String>{
        CloudPrefsStore.localStampKey: _stamp(9, 'ana'),
      }),
      owner: 'bob',
    );
    expect(await bob.getAll(), <String, Object>{'flutter.best': 2});
  });

  group('a non-local start replaces the mirror before stamping it', () {
    test('newer cloud copy stays newer after a write and reload', () async {
      final cloud = _FakeData(<String, String>{
        CloudPrefsStore.cloudKey: _envelope(20, 'ana', <String, Object>{
          'flutter.camp_progress_v1': 'xp500',
        }),
      });
      final stamp = _FakeData(<String, String>{
        CloudPrefsStore.localStampKey: _stamp(3, 'ana'),
      });
      final local = _local(<String, Object>{
        'flutter.camp_progress_v1': 'xp10',
      });
      final first = await _load(
        cloud: cloud,
        localStore: local,
        stamp: stamp,
        owner: 'ana',
      );
      await first.setValue('Bool', 'flutter.sound_muted_v1', true);

      final second = await _load(
        cloud: cloud,
        localStore: local,
        stamp: stamp,
        owner: 'ana',
      );
      expect(await second.getAll(), <String, Object>{
        'flutter.camp_progress_v1': 'xp500',
        'flutter.sound_muted_v1': true,
      });
      expect(await local.getAll(), await second.getAll());
    });

    test('a guest never inherits the previous player after a write', () async {
      final cloud = _FakeData();
      final stamp = _FakeData(<String, String>{
        CloudPrefsStore.localStampKey: _stamp(6, 'ana'),
      });
      final local = _local(<String, Object>{
        'flutter.camp_progress_v1': 'ana-xp',
      });
      final first = await _load(cloud: cloud, localStore: local, stamp: stamp);
      await first.setValue('Bool', 'flutter.sound_muted_v1', true);

      final second = await _load(cloud: cloud, localStore: local, stamp: stamp);
      expect(await second.getAll(), <String, Object>{
        'flutter.sound_muted_v1': true,
      });
      expect(await local.getAll(), <String, Object>{
        'flutter.sound_muted_v1': true,
      });
    });

    test('every value type is rewritten into the mirror', () async {
      final local = _local(<String, Object>{'flutter.old': 1});
      await _load(
        cloud: _FakeData(<String, String>{
          CloudPrefsStore.cloudKey: _envelope(2, 'ana', <String, Object>{
            'flutter.b': true,
            'flutter.i': 3,
            'flutter.d': 1.5,
            'flutter.s': 'x',
            'flutter.l': <String>['a'],
          }),
        }),
        localStore: local,
        owner: 'ana',
      );
      expect(await local.getAll(), <String, Object>{
        'flutter.b': true,
        'flutter.i': 3,
        'flutter.d': 1.5,
        'flutter.s': 'x',
        'flutter.l': <String>['a'],
      });
    });
  });

  test('unstamped local data loses to an existing cloud copy', () async {
    final store = await _load(
      cloud: _FakeData(<String, String>{
        CloudPrefsStore.cloudKey: _envelope(1, 'ana', <String, Object>{
          'flutter.best': 7,
        }),
      }),
      local: <String, Object>{'flutter.best': 99},
      owner: 'ana',
    );
    expect(await store.getAll(), <String, Object>{'flutter.best': 7});
  });

  test('remove, clear and filtered calls reach the cloud snapshot', () async {
    final cloud = _FakeData();
    final store = await _load(
      cloud: cloud,
      local: <String, Object>{'flutter.a': 1, 'flutter.b': 2, 'flutter.c': 3},
    );
    SharedPreferencesStorePlatform.instance = store;

    expect(
      await store.getAllWithParameters(
        GetAllParameters(
          filter: PreferencesFilter(
            prefix: 'flutter.',
            allowList: <String>{'flutter.a', 'flutter.c'},
          ),
        ),
      ),
      <String, Object>{'flutter.a': 1, 'flutter.c': 3},
    );
    await store.clearWithParameters(
      ClearParameters(
        filter: PreferencesFilter(
          prefix: 'flutter.',
          allowList: <String>{'flutter.c'},
        ),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('a');
    expect((cloud.envelope['values'] as Map).keys, <String>['flutter.b']);
    await prefs.clear();
    expect(cloud.envelope['values'], isEmpty);
  });

  test('stored lists are copied, not shared with the caller', () async {
    final cloud = _FakeData();
    final store = await _load(cloud: cloud);
    final list = <String>['a'];
    await store.setValue('StringList', 'flutter.l', list);
    list.add('b');
    expect((await store.getAll())['flutter.l'], <String>['a']);
  });

  test('a failing cloud write still saves locally', () async {
    final cloud = _FakeData()..failWrites = true;
    final local = _local(<String, Object>{});
    final store = await _load(cloud: cloud, localStore: local);
    expect(await store.setValue('Int', 'flutter.best', 3), isTrue);
    expect(await local.getAll(), <String, Object>{'flutter.best': 3});
  });

  test('corrupt snapshots and stamps are ignored', () async {
    expect(CloudPrefsStore.decodeEnvelope(null), isNull);
    expect(CloudPrefsStore.decodeEnvelope('not json'), isNull);
    expect(CloudPrefsStore.decodeEnvelope('[1,2]'), isNull);
    expect(
      CloudPrefsStore.decodeValues(<String, Object>{
        'flutter.a': <String, int>{'x': 1},
        'flutter.b': 2,
      }),
      <String, Object>{'flutter.b': 2},
    );
    expect(CloudPrefsStore.decodeStamp('{"rev":"x"}'), isNull);

    final store = await _load(
      cloud: _FakeData(<String, String>{CloudPrefsStore.cloudKey: '{broken'}),
      local: <String, Object>{'flutter.best': 7},
    );
    expect(await store.getAll(), <String, Object>{'flutter.best': 7});
  });

  test('a bare map from the first format reads as revision 0', () {
    final decoded = CloudPrefsStore.decodeEnvelope('{"flutter.best":4}')!;
    expect(decoded.stamp.revision, 0);
    expect(decoded.values, <String, Object>{'flutter.best': 4});
  });

  test('a failing data module surfaces so the caller keeps local', () {
    expect(() => _load(cloud: _FakeData()..failReads = true), throwsStateError);
  });

  test('daily streak and set rewards sync through the account copy', () async {
    final previous = SharedPreferencesStorePlatform.instance;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance = previous;
      SharedPreferences.resetStatic();
    });
    final cloud = _FakeData();
    SharedPreferencesStorePlatform.instance = await _load(
      cloud: cloud,
      owner: 'ana',
      local: <String, Object>{
        'flutter.${GameStorage.progressKey}': jsonEncode(<String, Object>{
          'version': 2,
          'level': 10,
          'maxCleared': 9,
          'legacyThrough': 10,
          'records': <String, Object>{
            for (var l = 1; l <= 9; l++) '$l': <String, int>{'stars': 1},
          },
        }),
      },
    );
    SharedPreferences.resetStatic();
    final day = dayIndexOf(DateTime(2026, 11, 8));
    final storage = await GameStorage.open(seedSource: () => 5);
    await storage.recordDailyClear(day, 70);
    await storage.recordClear(10, 40);

    final values = cloud.envelope['values'] as Map<String, dynamic>;
    final saved =
        jsonDecode(values['flutter.${GameStorage.progressKey}'] as String)
            as Map<String, dynamic>;
    expect((saved['daily'] as Map)['streak'], 1);
    expect(saved['setsAwarded'], <int>[0]);

    // Another device starts from the account copy.
    SharedPreferencesStorePlatform.instance = await _load(
      cloud: cloud,
      owner: 'ana',
    );
    SharedPreferences.resetStatic();
    final other = await GameStorage.open(seedSource: () => 6);
    expect(other.daily.streak.streak, 1);
    expect(other.dailyResultFor(day)!.seconds, 70);
    final replay = await other.recordClear(10, 30);
    expect(replay.completedSets, isEmpty, reason: 'set paid once');
  });
}
