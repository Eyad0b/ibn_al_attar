class TableRowData {
  final Map<String, dynamic> data;

  TableRowData({required this.data});

  factory TableRowData.fromMap(Map<String, dynamic> map) =>
      TableRowData(data: Map<String, dynamic>.from(map));

  Map<String, dynamic> toMap() => data;
}