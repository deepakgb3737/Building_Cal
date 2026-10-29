import 'dart:convert';
import 'dart:math';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_storage.dart';
import 'pvc_ceiling_calculator.dart';

class PvcProjectData {
  PvcProjectData._(this.shape, this.values, this.stock, this.corner,
      this.orientation, this.jointMode, this.distance, this.fromEnd);
  final PvcShape shape;
  final Map<String, String> values;
  final String stock, corner, distance;
  final PvcOrientation orientation;
  final PvcJointMode jointMode;
  final bool fromEnd;

  factory PvcProjectData.fromJson(Object? input) {
    try {
      if (input is! Map ||
          input['values'] is! Map ||
          input['fromEnd'] is! bool ||
          input['distance'] is! String) {
        throw const FormatException('Invalid project settings.');
      }
      final shape = PvcShape.values.byName(input['shape'] as String);
      final orientation =
          PvcOrientation.values.byName(input['orientation'] as String);
      final joint = PvcJointMode.values.byName(input['joint'] as String);
      final values = Map<String, String>.from(input['values'] as Map);
      final stock = input['stock'] as String,
          corner = input['corner'] as String;
      if (!['tr', 'tl', 'br', 'bl'].contains(corner) ||
          values.keys
              .toSet()
              .difference(pvcDimensions(shape).map((d) => d.key).toSet())
              .isNotEmpty) {
        throw const FormatException('Invalid room settings.');
      }
      final data = PvcProjectData._(
          shape,
          Map.unmodifiable(values),
          stock,
          corner,
          orientation,
          joint,
          input['distance'] as String,
          input['fromEnd'] as bool);
      final request = data.request;
      pvcStocks(stock);
      pvcJointPosition(request.room.points, orientation, request.jointRule);
      return data;
    } catch (_) {
      throw const FormatException(
          'Invalid or unsupported PVC project settings.');
    }
  }

  PvcCalculation get request =>
      PvcCalculation(buildPvcRoom(shape, values, corner: corner), stock,
          orientation: orientation,
          jointRule: PvcJointRule(
              mode: jointMode,
              distanceFt: double.tryParse(distance.replaceAll(',', '.')),
              fromEnd: fromEnd));

  Map<String, Object> toJson() => {
        'shape': shape.name,
        'values': values,
        'stock': stock,
        'corner': corner,
        'orientation': orientation.name,
        'joint': jointMode.name,
        'distance': distance,
        'fromEnd': fromEnd,
      };
}

class PvcProjectEntry {
  const PvcProjectEntry(this.id, this.name, {this.invalid = false});
  final String id, name;
  final bool invalid;
}

class PvcProjectRepository {
  PvcProjectRepository(this.storage);
  final DocumentStorage storage;
  bool _writing = false;

  static String validName(String input) {
    final name = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty ||
        name.length > 80 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(input)) {
      throw const FormatException('Use a project name of 1–80 characters.');
    }
    return name;
  }

  Map<String, dynamic> _decode(String id, String raw) {
    validateDocumentId(id);
    if (raw.length > 65536) {
      throw const FormatException('Project is too large.');
    }
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic> ||
        json['version'] != 1 ||
        json['id'] != id ||
        json['name'] is! String) {
      throw const FormatException('Invalid or unsupported PVC project.');
    }
    validName(json['name'] as String);
    PvcProjectData.fromJson(json['data']);
    return json;
  }

  Future<List<PvcProjectEntry>> list() async {
    final files = await storage.readAll(), entries = <PvcProjectEntry>[];
    for (final file in files.entries) {
      try {
        final json = _decode(file.key, file.value);
        entries.add(PvcProjectEntry(file.key, json['name'] as String));
      } catch (_) {
        entries.add(
            PvcProjectEntry(file.key, 'Unreadable project', invalid: true));
      }
    }
    entries
        .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return entries;
  }

  Future<PvcProjectData> open(String id) async {
    validateDocumentId(id);
    final raw = (await storage.readAll())[id];
    if (raw == null) {
      throw const FormatException('This project no longer exists.');
    }
    return PvcProjectData.fromJson(_decode(id, raw)['data']);
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    if (_writing) throw StateError('A project operation is already running.');
    _writing = true;
    try {
      return await action();
    } finally {
      _writing = false;
    }
  }

  Future<PvcProjectEntry> save(String input, PvcProjectData data,
          {String? id}) =>
      _write(() async {
        final name = validName(input);
        PvcProjectData.fromJson(data.toJson());
        if (id != null) validateDocumentId(id);
        final files = await storage.readAll();
        if (id != null && !files.containsKey(id)) {
          throw const FormatException(
              'Saved project was removed. Save it as a new project.');
        }
        for (final entry in await list()) {
          if (entry.id != id &&
              entry.name.toLowerCase() == name.toLowerCase()) {
            throw const FormatException(
                'That project name already exists. Choose another name.');
          }
        }
        String newId() => List.generate(
            4,
            (_) => Random.secure()
                .nextInt(0x100000000)
                .toRadixString(16)
                .padLeft(8, '0')).join();
        var target = id ?? newId();
        while (id == null && files.containsKey(target)) {
          target = newId();
        }
        final raw = jsonEncode(
            {'version': 1, 'id': target, 'name': name, 'data': data.toJson()});
        if (raw.length > 65536) {
          throw const FormatException('Project is too large.');
        }
        await storage.write(target, raw);
        return PvcProjectEntry(target, name);
      });

  Future<void> delete(String id) => _write(() async {
        validateDocumentId(id);
        await storage.delete(id);
      });
}
