import 'package:flutter/material.dart';
import 'package:ibn_al_attar/core/constants/app_colors.dart';
import 'package:ibn_al_attar/core/constants/app_strings.dart';
import 'package:ibn_al_attar/core/utils/validators.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool isRequired;
  final bool numericOnly;
  final int? maxLines;

  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.isRequired = false,
    this.numericOnly = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: numericOnly ? TextInputType.number : keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return AppStrings.errorRequired;
        }
        if (numericOnly && value?.isNotEmpty == true) {
          if (double.tryParse(value!) == null) {
            return AppStrings.validationNumberOnly;
          }
        }
        return validator?.call(value);
      },
    );
  }

  // Factory constructor for email field
  factory CustomTextField.email({
    required TextEditingController controller,
  }) {
    return CustomTextField(
      controller: controller,
      label: AppStrings.labelEmail,
      keyboardType: TextInputType.emailAddress,
      validator: Validators.validateEmail,
    );
  }

  // Factory constructor for password field
  factory CustomTextField.password({
    required TextEditingController controller,
  }) {
    return CustomTextField(
      controller: controller,
      label: AppStrings.labelPassword,
      obscureText: true,
      validator: Validators.validatePassword,
    );
  }
}
