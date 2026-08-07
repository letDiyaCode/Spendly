import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/repository_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/shared_widgets.dart';
import '../auth/auth_provider.dart';

import 'package:image_picker/image_picker.dart';
import '../../core/services/cloudinary_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  bool _isLoading = false;
  String? _newAvatarUrl;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameController = TextEditingController(text: user?.name ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _newAvatarUrl = user?.avatarUrl;
  }

  // ... dispose ...

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final url = await ref.read(cloudinaryServiceProvider).uploadXFile(image);
      if (url != null) {
        setState(() => _newAvatarUrl = url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to upload image. Please check your Cloudinary preset.',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authProvider);
      if (user == null) return;

      final updatedUser = user.copyWith(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        avatarUrl: _newAvatarUrl,
      );

      await ref.read(userRepositoryProvider).saveUser(updatedUser);
      
      // Invalidate authProvider to reflect changes
      ref.invalidate(authProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar section
              Center(
                child: Stack(
                  children: [
                    UserAvatar(
                      name: _nameController.text,
                      userId: user?.id ?? '',
                      size: 100,
                      avatarUrl: _newAvatarUrl,
                      isVerified: user?.isVerified ?? false,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: SpendlyColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
// ...
              const SizedBox(height: 32),
              
              SpendlyTextField(
                label: 'Display Name',
                controller: _nameController,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),
              
              SpendlyTextField(
                label: 'Bio',
                controller: _bioController,
                maxLines: 3,
                hint: 'Tell others a bit about yourself...',
              ),
              
              if (user?.isVerified ?? false) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.verified, color: SpendlyColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Verified Payee',
                      style: AppTextStyles.bodyPrimary().copyWith(
                        color: SpendlyColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
