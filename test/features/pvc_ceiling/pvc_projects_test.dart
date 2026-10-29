import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_storage.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_files_io.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_projects.dart';
import 'package:grid_ceiling_calculator/features/pvc_ceiling/logic/pvc_ceiling_calculator.dart';

class PvcMemoryStorage implements DocumentStorage {
  final files = <String, String>{};
  bool failWrite = false, failRead = false, failDelete = false;
  @override
  Future<Map<String, String>> readAll() async {
    if (failRead) throw StateError('read failed');
    return Map.of(files);
  }

  @override
  Future<void> write(String id, String content) async {
    if (failWrite) throw StateError('disk full');
    files[id] = content;
  }

  @override
  Future<void> delete(String id) async {
    if (failDelete) throw StateError('delete failed');
    files.remove(id);
  }
}

PvcProjectData pvcProjectFixture({PvcShape shape = PvcShape.rectangle}) =>
    PvcProjectData.fromJson({
      'shape': shape.name,
      'values': pvcDefaults(shape),
      'stock': 'mix',
      'corner': 'tl',
      'orientation': 'length',
      'joint': 'custom',
      'distance': '4',
      'fromEnd': true,
    });
void main() {
  test(
      'Every room shape and complete settings round trip across repository instances',
      () async {
    final storage = PvcMemoryStorage();
    for (final shape in PvcShape.values) {
      final data = pvcProjectFixture(shape: shape);
      final entry =
          await PvcProjectRepository(storage).save('Site ${shape.name}', data);
      final restored = await PvcProjectRepository(storage).open(entry.id);
      expect(restored.toJson(), data.toJson());
    }
    expect(await PvcProjectRepository(storage).list(), hasLength(6));
  });
  test('Native file write survives repository restart and deletion', () async {
    final dir = await Directory.systemTemp.createTemp('pvc-projects-');
    addTearDown(() => dir.delete(recursive: true));
    final repo = PvcProjectRepository(FileDocumentStorage(directory: dir));
    final entry = await repo.save('Living room', pvcProjectFixture());
    final reopened = PvcProjectRepository(FileDocumentStorage(directory: dir));
    expect(
        (await reopened.open(entry.id)).toJson(), pvcProjectFixture().toJson());
    await reopened.delete(entry.id);
    expect(await repo.list(), isEmpty);
    expect(FileDocumentStorage().namespace, 'easy_floor_documents');
    expect(() => FileDocumentStorage(namespace: '../escape'),
        throwsFormatException);
  });
  test(
      'Unique names, explicit updates, failed writes and deletion protect saved data',
      () async {
    final storage = PvcMemoryStorage(), data = pvcProjectFixture();
    final repo = PvcProjectRepository(storage);
    final entry = await repo.save('  Site   One ', data);
    expect(entry.name, 'Site One');
    await expectLater(repo.save('site one', data), throwsFormatException);
    final before = Map.of(storage.files);
    storage.failWrite = true;
    await expectLater(
        repo.save('Site One', data, id: entry.id), throwsStateError);
    expect(storage.files, before);
    storage.failWrite = false;
    expect((await repo.save('Site One', data, id: entry.id)).id, entry.id);
    storage.failDelete = true;
    await expectLater(repo.delete(entry.id), throwsStateError);
    expect(storage.files, hasLength(1));
    storage.failDelete = false;
    await repo.delete(entry.id);
    await expectLater(repo.open(entry.id), throwsFormatException);
    await expectLater(
        repo.save('Site One', data, id: entry.id), throwsFormatException);
    for (final name in ['', '   ', 'bad\nname', 'a' * 81]) {
      await expectLater(repo.save(name, data), throwsFormatException);
    }
    await expectLater(repo.delete('../x'), throwsFormatException);
  });
  test(
      'Corrupt and unsupported projects are never applied and remain deletable',
      () async {
    final storage = PvcMemoryStorage(),
        repo = PvcProjectRepository(PvcMemoryStorage());
    final good = await repo.save('Good', pvcProjectFixture());
    final raw = (repo.storage as PvcMemoryStorage).files[good.id]!;
    storage.files['corrupt'] = 'not json';
    final bad = jsonDecode(raw) as Map<String, dynamic>;
    bad['version'] = 99;
    bad['id'] = 'newer';
    storage.files['newer'] = jsonEncode(bad);
    final r = PvcProjectRepository(storage);
    expect((await r.list()).every((e) => e.invalid), isTrue);
    await expectLater(r.open('corrupt'), throwsFormatException);
    await expectLater(r.open('newer'), throwsFormatException);
    await r.delete('corrupt');
    expect(storage.files.containsKey('newer'), isTrue);
    for (final change in <String, Object>{
      'orientation': 'bad',
      'stock': '20',
      'corner': 'bad',
      'fromEnd': 'yes',
      'values': {'A': 'NaN', 'B': '8'}
    }.entries) {
      expect(
          () => PvcProjectData.fromJson(
              {...pvcProjectFixture().toJson(), change.key: change.value}),
          throwsFormatException);
    }
  });
}
