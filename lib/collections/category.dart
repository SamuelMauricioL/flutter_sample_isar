import 'package:isar/isar.dart';

part 'category.g.dart';

@Collection()
class Category {
  /// auto increment ID
  @Id()
  int id = Isar.autoIncrement;

  /// category name
  late String name;
}
