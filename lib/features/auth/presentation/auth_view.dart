import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/l10n.dart';
import 'auth_cubit.dart';

/// Lightweight Login / Register screen shown before entering the 3-screen app.
class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    context.read<AuthCubit>().clearError();
    _confirmPasswordController.clear();
    setState(() {
      _isRegisterMode = !_isRegisterMode;
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<AuthCubit>();
    if (_isRegisterMode) {
      cubit.register(_emailController.text, _passwordController.text);
    } else {
      cubit.signIn(_emailController.text, _passwordController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  final isUnconfigured =
                      state.status == AuthStatus.unconfigured;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _SpendlyLogoHeader(),
                      const SizedBox(height: 28),
                      if (isUnconfigured) ...[
                        const _FirebaseSetupNotice(),
                        const SizedBox(height: 16),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _isRegisterMode
                                      ? context.l10n.createAccountTitle
                                      : context.l10n.welcomeBack,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isRegisterMode
                                      ? 'Start tracking your monthly expenses in EGP.'
                                      : 'Sign in to view your expenses and budget.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 20),
                                if (state.errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.dangerSurface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      state.errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  enabled:
                                      !state.isSubmitting && !isUnconfigured,
                                  decoration: InputDecoration(
                                    labelText: context.l10n.email,
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                    ),
                                  ),
                                  validator: (value) {
                                    final text = value?.trim() ?? '';
                                    if (text.isEmpty) {
                                      return 'Email is required.';
                                    }
                                    if (!text.contains('@') ||
                                        !text.contains('.')) {
                                      return 'Enter a valid email address.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: _isRegisterMode
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                                  enabled:
                                      !state.isSubmitting && !isUnconfigured,
                                  onFieldSubmitted: _isRegisterMode
                                      ? null
                                      : (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: context.l10n.password,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    final text = value ?? '';
                                    if (text.isEmpty) {
                                      return 'Password is required.';
                                    }
                                    if (_isRegisterMode && text.length < 6) {
                                      return 'Use at least 6 characters.';
                                    }
                                    return null;
                                  },
                                ),
                                if (_isRegisterMode) ...[
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    textInputAction: TextInputAction.done,
                                    enabled:
                                        !state.isSubmitting && !isUnconfigured,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: context.l10n.confirmPassword,
                                      prefixIcon: const Icon(
                                        Icons.lock_reset_outlined,
                                      ),
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword;
                                          });
                                        },
                                        icon: Icon(
                                          _obscureConfirmPassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (!_isRegisterMode) return null;
                                      final text = value ?? '';
                                      if (text.isEmpty) {
                                        return 'Please confirm your password.';
                                      }
                                      if (text != _passwordController.text) {
                                        return 'Passwords do not match.';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton(
                                  onPressed:
                                      (state.isSubmitting || isUnconfigured)
                                      ? null
                                      : _submit,
                                  child: state.isSubmitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          _isRegisterMode
                                              ? context.l10n.createAccount
                                              : context.l10n.signIn,
                                        ),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: state.isSubmitting
                                      ? null
                                      : _toggleMode,
                                  child: Text(
                                    _isRegisterMode
                                        ? 'Already have an account? Sign in'
                                        : 'New to Spendly? Create an account',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpendlyLogoHeader extends StatelessWidget {
  const _SpendlyLogoHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.bar_chart_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spendly',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Personal Expense Tracker',
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FirebaseSetupNotice extends StatelessWidget {
  const _FirebaseSetupNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sandyAccent),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Firebase setup required',
            style: TextStyle(
              color: AppColors.darkPlum,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Run `flutterfire configure` to generate `firebase_options.dart`, enable Email/Password Auth and Cloud Firestore, and deploy `firestore.rules`. See README.md for details.',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
