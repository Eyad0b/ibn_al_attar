import 'package:equatable/equatable.dart';

enum DataType { text, number, date }

class TableColumn extends Equatable {
  final String name;
  final DataType type;

  const TableColumn({required this.name, required this.type});

  TableColumn copyWith({String? name, DataType? type}) {
    return TableColumn(
      name: name ?? this.name,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.toString().split('.').last,
    };
  }

  factory TableColumn.fromMap(Map<String, dynamic> map) {
    return TableColumn(
      name: map['name'] as String,
      type: DataType.values.firstWhere(
            (e) => e.toString() == 'DataType.${map['type']}',
        orElse: () => DataType.text,
      ),
    );
  }

  @override
  List<Object> get props => [name, type];
}