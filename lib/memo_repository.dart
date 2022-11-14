import 'dart:async';

import 'package:isar/isar.dart';

import 'collections/category.dart';
import 'collections/memo.dart';

/// Notes repository
///
/// Operations related to memos are performed via this class
class MemoRepository {
  MemoRepository(
    this.isar, {
    this.sync = false,
  }) {
    // Monitor changes in the memo list and send them to the stream
    isar.memos.watchLazy().listen((_) async {
      if (!isar.isOpen) {
        return;
      }
      if (_memoStreamController.isClosed) {
        return;
      }
      _memoStreamController.sink.add(await findMemos());
    });
  }

  /// Isar instance
  final Isar isar;

  /// asynchronous or not
  final bool sync;

  /// If you want to monitor the memo list, have memoStream listen.
  final _memoStreamController = StreamController<List<Memo>>.broadcast();
  Stream<List<Memo>> get memoStream => _memoStreamController.stream;

  /// End processing
  void dispose() {
    _memoStreamController.close();
  }

  /// Search categories
  FutureOr<List<Category>> findCategories() async {
    if (!isar.isOpen) {
      return [];
    }

    // Default sort is ascending by id
    final builder = isar.categorys.where();
    return sync ? builder.findAllSync() : await builder.findAll();
  }

  /// Search notes
  FutureOr<List<Memo>> findMemos() async {
    if (!isar.isOpen) {
      return [];
    }

    // Return all records in descending order of update date/time
    final builder = isar.memos.where().sortByUpdatedAtDesc();

    if (sync) {
      final memos = builder.findAllSync();
      // Need to load categories linked with IsarLink
      for (final memo in memos) {
        memo.category.loadSync();
      }
      return memos;
    }

    final memos = await builder.findAll();

    // Need to load categories linked with IsarLink
    for (final memo in memos) {
      await memo.category.load();
    }
    return memos;
  }

  /// add a note
  FutureOr<void> addMemo({
    required Category category,
    required String content,
  }) {
    if (!isar.isOpen) {
      return Future<void>(() {});
    }

    final now = DateTime.now();
    final memo = Memo()
      ..category.value = category
      ..content = content
      ..createdAt = now
      ..updatedAt = now;
    if (sync) {
      isar.writeTxnSync<void>((_) {
        isar.memos.putSync(memo);

        // Need to save categories linked with IsarLink
        memo.category.saveSync();
      });
    } else {
      return isar.writeTxn((_) async {
        await isar.memos.put(memo);

        // Need to save categories linked with IsarLink
        await memo.category.save();
      });
    }
  }

  /// update notes
  FutureOr<void> updateMemo({
    required Memo memo,
    required Category category,
    required String content,
  }) {
    if (!isar.isOpen) {
      return Future<void>(() {});
    }

    final now = DateTime.now();
    memo
      ..category.value = category
      ..content = content
      ..updatedAt = now;
    if (sync) {
      isar.writeTxnSync<void>((_) {
        isar.memos.putSync(memo);

        // Need to save categories linked with IsarLink
        memo.category.saveSync();
      });
    } else {
      return isar.writeTxn((_) async {
        await isar.memos.put(memo);

        // Need to save categories linked with IsarLink
        await memo.category.save();
      });
    }
  }

  /// delete notes
  FutureOr<bool> deleteMemo(Memo memo) async {
    if (!isar.isOpen) {
      return false;
    }
    if (sync) {
      return isar.writeTxnSync((_) {
        return isar.memos.deleteSync(memo.id);
      });
    }
    return isar.writeTxn((_) async {
      return isar.memos.delete(memo.id);
    });
  }
}
