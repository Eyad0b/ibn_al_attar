class ColumnDependency {
  final String sourceColumn;
  final String targetColumn;
  final String operation;

  const ColumnDependency({
    required this.sourceColumn,
    required this.targetColumn,
    required this.operation,
  });
}