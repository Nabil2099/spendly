import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';

enum AuthStatus { unknown, unconfigured, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.isSubmitting = false,
    this.errorMessage,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.unconfigured() : this(status: AuthStatus.unconfigured);

  final AuthStatus status;
  final AppUser? user;
  final bool isSubmitting;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool clearUser = false,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required this._repository, required bool isFirebaseConfigured})
    : super(
        isFirebaseConfigured
            ? const AuthState.unknown()
            : const AuthState.unconfigured(),
      ) {
    if (isFirebaseConfigured && _repository != null) {
      final current = _repository.currentUser;
      emit(
        AuthState(
          status: current != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated,
          user: current,
        ),
      );
      _subscription = _repository.authStateChanges().listen((user) {
        emit(
          AuthState(
            status: user != null
                ? AuthStatus.authenticated
                : AuthStatus.unauthenticated,
            user: user,
          ),
        );
      });
    }
  }

  final AuthRepository? _repository;
  StreamSubscription<AppUser?>? _subscription;

  Future<void> signIn(String email, String password) async {
    await _submit(() => _repository!.signIn(email, password));
  }

  Future<void> register(String email, String password) async {
    await _submit(() => _repository!.register(email, password));
  }

  Future<void> signOut() async {
    await _repository?.signOut();
  }

  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  Future<void> _submit(Future<void> Function() action) async {
    if (_repository == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await action();
    } on AuthFailure catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
