import 'package:ibn_al_attar/core/constants/app_strings.dart';
import 'package:ibn_al_attar/data/models/table_column.dart';

class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return AppStrings.errorRequired;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return AppStrings.errorEmailInvalid;
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return AppStrings.errorRequired;
    if (value.length < 8) return AppStrings.errorPasswordWeak;
    return null;
  }

  static String? validateRequired(String? value) {
    if (value == null || value.isEmpty) return AppStrings.errorRequired;
    return null;
  }

  static String? validateNumeric(String? value) {
    if (value == null || value.isEmpty) return null;
    if (double.tryParse(value) == null) return AppStrings.validationNumberOnly;
    return null;
  }

  static String? validatePositiveNumber(String? value) {
    final numericError = validateNumeric(value);
    if (numericError != null) return numericError;
    if (double.parse(value!) <= 0) return AppStrings.validationPositiveNumber;
    return null;
  }

  static String? validateColumnName(String? name, List<TableColumn> columns) {
    if (name == null || name.isEmpty) return 'Column name cannot be empty';
    if (columns.any((c) => c.name == name)) return 'Column name must be unique';
    return null;
  }

  static String? validateNumericValue(String? value) {
    if (value == null || value.isEmpty) return 'Value cannot be empty';
    if (num.tryParse(value) == null) return 'Must be a valid number';
    return null;
  }

}