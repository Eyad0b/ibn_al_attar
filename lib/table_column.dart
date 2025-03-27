// table_column.dart
enum DataType { text, number, date }

class TableColumn {
  String name;
  DataType type;

  TableColumn({required this.name, required this.type});

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
}