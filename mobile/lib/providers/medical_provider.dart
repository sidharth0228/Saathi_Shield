import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medical_profile_model.dart';
import '../repositories/medical_repository.dart';
import 'auth_provider.dart';

class MedicalState {
  final MedicalProfileModel? profile;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  const MedicalState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
  });

  MedicalState copyWith({
    MedicalProfileModel? profile,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return MedicalState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

final medicalRepositoryProvider = Provider<MedicalRepository>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return MedicalRepository(apiService);
});

class MedicalNotifier extends StateNotifier<MedicalState> {
  final MedicalRepository _repository;

  MedicalNotifier(this._repository) : super(const MedicalState()) {
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final profile = await _repository.getMedicalProfile();
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> updateProfile(MedicalProfileModel newProfile) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final updatedProfile = await _repository.updateMedicalProfile(newProfile);
      state = state.copyWith(profile: updatedProfile, isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final medicalProvider = StateNotifierProvider<MedicalNotifier, MedicalState>((ref) {
  final repository = ref.watch(medicalRepositoryProvider);
  return MedicalNotifier(repository);
});
