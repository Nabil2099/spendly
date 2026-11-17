import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/locale_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/l10n/l10n.dart';
import '../../auth/presentation/auth_cubit.dart';
import 'profile_cubit.dart';

/// User profile screen for editing name, bio, profile picture, dark mode, and logging out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  String? _pendingPhotoBase64;
  bool _clearPhoto = false;
  bool _initializedFromState = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileCubit>().state.profile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _pendingPhotoBase64 = profile?.photoBase64;
    if (profile != null) {
      _initializedFromState = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pendingPhotoBase64 = base64Encode(bytes);
      _clearPhoto = false;
    });
  }

  void _removePhoto() {
    setState(() {
      _pendingPhotoBase64 = null;
      _clearPhoto = true;
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final cubit = context.read<ProfileCubit>();
    final ok = await cubit.saveProfile(
      name: _nameController.text,
      bio: _bioController.text,
      photoBase64: _pendingPhotoBase64,
      clearPhoto: _clearPhoto,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Profile saved.'
              : (cubit.state.errorMessage ?? 'Could not save profile.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = context.select(
      (AuthCubit cubit) => cubit.state.user?.email ?? '',
    );
    final isDark = context.select(
      (ThemeCubit cubit) =>
          cubit.state == ThemeMode.dark ||
          (cubit.state == ThemeMode.system && context.isDarkMode),
    );
    final currentLocale = context.select((LocaleCubit cubit) => cubit.state);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profile), centerTitle: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: BlocConsumer<ProfileCubit, ProfileState>(
              listener: (context, state) {
                if (!_initializedFromState && state.profile != null) {
                  _nameController.text = state.profile!.name;
                  _bioController.text = state.profile!.bio;
                  _pendingPhotoBase64 = state.profile!.photoBase64;
                  _initializedFromState = true;
                }
              },
              builder: (context, state) {
                final photoBytes = _decodePhoto(_pendingPhotoBase64);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  GestureDetector(
                                    onTap: state.isSaving ? null : _pickImage,
                                    child: CircleAvatar(
                                      radius: 48,
                                      backgroundColor: context.greenTint,
                                      backgroundImage: photoBytes != null
                                          ? MemoryImage(photoBytes)
                                          : null,
                                      child: photoBytes == null
                                          ? Icon(
                                              Icons.person_rounded,
                                              size: 46,
                                              color: AppColors.primaryGreen,
                                            )
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: state.isSaving ? null : _pickImage,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGreen,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: context.cardBg,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (photoBytes != null) ...[
                                const SizedBox(height: 6),
                                TextButton(
                                  onPressed: state.isSaving
                                      ? null
                                      : _removePhoto,
                                  child: const Text('Remove photo'),
                                ),
                              ],
                              const SizedBox(height: 10),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _nameController,
                                builder: (context, nameValue, _) {
                                  final displayName = nameValue.text.trim();
                                  if (displayName.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      displayName,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              if (userEmail.isNotEmpty)
                                Text(
                                  userEmail,
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _nameController,
                                  enabled: !state.isSaving,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: l10n.name,
                                    hintText: 'Your display name',
                                    prefixIcon: const Icon(
                                      Icons.badge_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _bioController,
                                  enabled: !state.isSaving,
                                  maxLines: 3,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    labelText: l10n.bio,
                                    hintText: 'A short note about yourself...',
                                    prefixIcon: const Icon(Icons.notes_rounded),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                FilledButton(
                                  onPressed: state.isSaving ? null : _save,
                                  child: state.isSaving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(l10n.saveProfile),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(
                                  l10n.darkMode,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(l10n.darkModeSubtitle),
                                secondary: Icon(
                                  isDark
                                      ? Icons.dark_mode_rounded
                                      : Icons.light_mode_rounded,
                                  color: AppColors.primaryGreen,
                                ),
                                value: isDark,
                                onChanged: (value) {
                                  context.read<ThemeCubit>().toggleDarkMode(
                                    value,
                                  );
                                },
                              ),
                              Divider(height: 1, color: context.borderColor),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.translate_rounded,
                                      color: AppColors.slateBlue,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        l10n.language,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    SegmentedButton<String>(
                                      segments: [
                                        ButtonSegment(
                                          value: 'en',
                                          label: Text(l10n.english),
                                        ),
                                        ButtonSegment(
                                          value: 'ar',
                                          label: Text(l10n.arabic),
                                        ),
                                      ],
                                      selected: {currentLocale.languageCode},
                                      showSelectedIcon: false,
                                      style: const ButtonStyle(
                                        visualDensity: VisualDensity.compact,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onSelectionChanged: (val) {
                                        context.read<LocaleCubit>().setLocale(
                                          Locale(val.first),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            context.pop();
                            context.read<AuthCubit>().signOut();
                          },
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: AppColors.danger,
                          ),
                          label: Text(
                            l10n.logOut,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Uint8List? _decodePhoto(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      return base64Decode(base64String);
    } catch (_) {
      return null;
    }
  }
}
