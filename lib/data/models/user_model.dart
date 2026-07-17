// import 'package:hive/hive.dart';

// part 'user_model.g.dart';

// @HiveType(typeId: 0)
class UserModel {
  // @HiveField(0)
  final String id;
  
  // @HiveField(1)
  final String name;
  
  // @HiveField(2)
  final String email;
  
  // @HiveField(3)
  final String role; // 'user', 'trainer', 'admin'
  
  // @HiveField(4)
  final int level;
  
  // @HiveField(5)
  final int xp;
  
  // @HiveField(6)
  final List<String> badges;
  
  // @HiveField(7)
  final String? avatarType; // 'male' ou 'female'

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'user',
    this.level = 1,
    this.xp = 0,
    this.badges = const [],
    this.avatarType,
  });
}
