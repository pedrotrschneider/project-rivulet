import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../profiles_provider.dart';
import '../models/profile.dart';
import 'create_profile_dialog.dart';

/// A Netflix-style profile selection screen.
/// Displays a grid of profile avatars with names and an "Add Profile" option.
class ProfileSelectionScreen extends ConsumerWidget {
  const ProfileSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.deepPurple.shade900, Colors.black],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    "Who's Watching?",
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Profile Grid
                  profilesAsync.when(
                    data: (profiles) => _ProfileGrid(profiles: profiles),
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load profiles',
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.invalidate(profilesProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileGrid extends ConsumerWidget {
  final List<Profile> profiles;

  const _ProfileGrid({required this.profiles});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 24,
      children: [
        // Existing profiles
        ...profiles.map((profile) => _ProfileCard(profile: profile)),
        // Add Profile button
        const _AddProfileCard(),
      ],
    );
  }
}

class _ProfileCard extends ConsumerStatefulWidget {
  final Profile profile;

  const _ProfileCard({required this.profile});

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () async {
          await ref
              .read(selectedProfileProvider.notifier)
              .select(widget.profile.id);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isHovered ? 1.1 : 1.0),
          transformAlignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isHovered ? Colors.white : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: widget.profile.avatar.isNotEmpty
                      ? Image.network(
                          widget.profile.avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultAvatar(),
                        )
                      : _defaultAvatar(),
                ),
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                widget.profile.name,
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.grey.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: Colors.deepPurple.shade700,
      child: const Icon(Icons.person, size: 60, color: Colors.white70),
    );
  }
}

class _AddProfileCard extends ConsumerStatefulWidget {
  const _AddProfileCard();

  @override
  ConsumerState<_AddProfileCard> createState() => _AddProfileCardState();
}

class _AddProfileCardState extends ConsumerState<_AddProfileCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _showCreateProfileDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(_isHovered ? 1.1 : 1.0),
          transformAlignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isHovered ? Colors.white : Colors.grey.shade600,
                    width: 3,
                  ),
                  color: Colors.grey.shade900.withOpacity(0.5),
                ),
                child: Icon(
                  Icons.add,
                  size: 60,
                  color: _isHovered ? Colors.white : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              // Label
              Text(
                'Add Profile',
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateProfileDialog(),
    );
  }
}
