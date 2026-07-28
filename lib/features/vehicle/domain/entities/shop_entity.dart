import 'package:equatable/equatable.dart';

class ShopEntity extends Equatable {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final DateTime? createdAt;

  const ShopEntity({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    this.createdAt,
  });

  ShopEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? notes,
    DateTime? createdAt,
  }) {
    return ShopEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, phone, address, notes, createdAt];
}
