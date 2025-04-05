import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ibn_al_attar/core/constants/app_colors.dart';
import 'package:ibn_al_attar/core/constants/app_strings.dart';
import 'package:ibn_al_attar/core/utils/validators.dart';
import 'package:ibn_al_attar/core/widgets/custom_text_field.dart';
import 'package:ibn_al_attar/features/admin_panel/admin_panel_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user?.email == AppStrings.adminEmail) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
        );
      } else {
        await FirebaseAuth.instance.signOut();
        setState(() => _errorMessage = AppStrings.accessDenied);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? AppStrings.authError);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        backgroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 30,
                        horizontal: 20,
                      ),
                      child: Form(
                        key: _formKey,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 400,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppStrings.login,
                                style: Theme.of(context).textTheme.headline5,
                              ),
                              const SizedBox(height: 30),
                              CustomTextField.email(
                                  controller: _emailController),
                              const SizedBox(height: 20),
                              CustomTextField.password(
                                  controller: _passwordController),
                              if (_errorMessage != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 15),
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: AppColors.error),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              const SizedBox(height: 30),
                              _isLoading
                                  ? const CircularProgressIndicator()
                                  : SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          AppStrings.login,
                                          style: TextStyle(
                                            color: AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
