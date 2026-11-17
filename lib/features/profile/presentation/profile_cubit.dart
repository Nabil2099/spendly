import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/profile_repository.dart';

class ProfileState {
  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final UserProfile? profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  ProfileState copyWith({
    UserProfile? profile,
    bool clearProfile = false,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({required this._repository}) : super(const ProfileState());

  final ProfileRepository _repository;
  String? _uid;
  StreamSubscription<UserProfile?>? _sub;

  Future<void> bindUser(String? uid) async {
    if (_uid == uid && uid != null) return;
    _uid = uid;
    await _sub?.cancel();
    _sub = null;

    if (uid == null) {
      emit(const ProfileState());
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));
    _sub = _repository
        .watchProfile(uid)
        .listen(
          (profile) {
            emit(
              state.copyWith(
                profile: profile ?? UserProfile(uid: uid),
                isLoading: false,
                clearError: true,
              ),
            );
          },
          onError: (_) {
            emit(
              state.copyWith(
                isLoading: false,
                errorMessage: 'Could not load profile.',
              ),
            );
          },
        );
  }

  Future<bool> saveProfile({
    required String name,
    required String bio,
    String? photoBase64,
    bool clearPhoto = false,
  }) async {
    final uid = _uid;
    if (uid == null) return false;

    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final current = state.profile ?? UserProfile(uid: uid);
      final updated = current.copyWith(
        name: name.trim(),
        bio: bio.trim(),
        photoBase64: photoBase64,
        clearPhoto: clearPhoto,
        updatedAt: DateTime.now(),
      );
      await _repository.saveProfile(updated);
      emit(state.copyWith(profile: updated, isSaving: false));
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to save profile. Please try again.',
        ),
      );
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
