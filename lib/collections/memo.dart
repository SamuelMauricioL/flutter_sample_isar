import 'package:isar/isar.dart';

import 'category.dart';

part 'memo.g.dart';

@Collection()
class Memo {
  /// auto increment ID
  @Id()
  int id = Isar.autoIncrement;

  /// category
  final category = IsarLink<Category>();

  /// Contents of the memo
  late String content;

  /// creation date
  late DateTime createdAt;

  /// Updated date and time
  @Index()
  late DateTime updatedAt;
}
