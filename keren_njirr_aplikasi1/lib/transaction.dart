import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
class Transaction extends HiveObject {
  @HiveField(0)
  late String type;

  @HiveField(1)
  late String description;

  @HiveField(2)
  late double amount;

  @HiveField(3)
  late DateTime createdAt;
}