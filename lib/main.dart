// ignore_for_file: avoid_print, unused_element

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'collections/category.dart';
import 'collections/memo.dart';
import 'memo_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the notes repository
  // path_provider is not web ready
  var path = '';
  if (!foundation.kIsWeb) {
    final dir = await getApplicationSupportDirectory();
    path = dir.path;
  }

  final isar = await Isar.open(
    schemas: [
      CategorySchema,
      MemoSchema,
    ],
    directory: path,
  );

  // Initial data write
  // If the force property is set to true, delete all existing data
  // and rewrite the initial data
  await _writeSeedIfNeed(
    isar,
    force: true,
  );

  // await _experiments(isar);

  // Synchronize DB operations by setting the sync property to true
  runApp(
    App(
      memoRepository: MemoRepository(
        isar,
        // sync: true,
      ),
    ),
  );
}

/// Write initial data if necessary
Future<void> _writeSeedIfNeed(
  Isar isar, {
  bool force = false,
}) async {
  if (force) {
    // Forcibly delete all data
    await isar.writeTxn((_) async {
      await isar.clear();
    });
  }

  // do nothing with data
  if (await isar.categorys.count() > 0) {
    return;
  }

  // write initial data
  await isar.writeTxn((_) async {
    // Initial data for categories
    await isar.categorys.putAll(
      ['Rutina', 'Trabajo'].map((name) => Category()..name = name).toList(),
    );
    final categories = await isar.categorys.where().findAll();

    // The initial data of the memo is fetched from JSON
    // final bytes = await rootBundle.load('assets/json/seed_memos.json');
    // final jsonString = const Utf8Decoder().convert(bytes.buffer.asUint8List());
    final jsonArray = json.decode(
      json.encode([
        {'categoryName': 'Rutina', 'content': 'Comer'},
        {'categoryName': 'Rutina', 'content': 'Dormir zzz'},
        {'categoryName': 'Rutina', 'content': 'Tomar'},
        {'categoryName': 'Trabajo', 'content': 'task 505'},
        {'categoryName': 'Trabajo', 'content': 'task 504'},
        {'categoryName': 'Trabajo', 'content': 'task 503'},
      ]),
    ) as List;

    final memos = <Memo>[];
    for (final jsonMap in jsonArray) {
      if (jsonMap is Map<String, dynamic>) {
        final now = DateTime.now();
        memos.add(
          Memo()
            ..category.value = categories.firstWhere(
              (category) => category.name == jsonMap['categoryName'] as String,
            )
            ..content = jsonMap['content'] as String
            ..createdAt = now
            ..updatedAt = now,
        );
      }
    }

    await isar.memos.putAll(memos);
    final saveCategories = memos.map((memo) => memo.category).toList();
    for (final saveCategory in saveCategories) {
      await saveCategory.save();
    }
  });
}

/// Measurement experiment
Future<void> _experiments(Isar isar) async {
  // The number of notes added in the experiment
  const count = 1;

  final categories = await isar.categorys.where().findAll();
  final memos = <Memo>[];
  for (var i = 0; i < count; i++) {
    final now = DateTime.now();
    final memo = Memo()
      ..category.value = categories.first
      ..content = 'content'
      ..createdAt = now
      ..updatedAt = now;
    memos.add(memo);
  }

  await _clearMemos(isar);
  await _measure('put', () async {
    await isar.writeTxn((_) async {
      for (final memo in memos) {
        await isar.memos.put(memo);
        await memo.category.save();
      }
    });
  });

  await _clearMemos(isar);
  await _measure('putAll', () async {
    await isar.writeTxn((_) async {
      await isar.memos.putAll(memos);
      final saveCategories = memos.map((memo) => memo.category).toList();
      for (final saveCategory in saveCategories) {
        await saveCategory.save();
      }
    });
  });

  await _clearMemos(isar);
  await _measure('putSync', () {
    isar.writeTxnSync((_) {
      for (final memo in memos) {
        isar.memos.putSync(memo);
        memo.category.saveSync();
      }
    });
  });

  await _clearMemos(isar);
  await _measure('putAllSync', () {
    isar.writeTxnSync((_) {
      isar.memos.putAllSync(memos);
      final saveCategories = memos.map((memo) => memo.category).toList();
      for (final saveCategory in saveCategories) {
        saveCategory.saveSync();
      }
    });
  });
}

Future<void> _measure(
  String functionName,
  FutureOr<void> Function() body,
) async {
  final startTime = DateTime.now();
  await body();
  final endTime = DateTime.now();
  final elapsedTime = endTime.difference(startTime);
  print('$functionName(): Time: $elapsedTime');
}

Future<void> _clearMemos(Isar isar) async {
  await isar.writeTxn((_) async {
    await isar.memos.clear();
  });
}
