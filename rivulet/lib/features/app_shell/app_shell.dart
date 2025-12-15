import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../search/search_screen.dart';
import '../library/library_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/profiles_provider.dart';

/// Main app shell with Stremio-style side navigation.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: 'Discover',
    ),
    _NavItem(
      icon: Icons.video_library_outlined,
      selectedIcon: Icons.video_library,
      label: 'Library',
    ),
    // Future tabs can be added here
    // _NavItem(icon: Icons.download_outlined, selectedIcon: Icons.download, label: 'Downloads'),
    // _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings, label: 'Settings'),
  ];

  Widget _buildScreen() {
    switch (_selectedIndex) {
      case 0:
        return const DiscoveryScreen();
      case 1:
        return const LibraryScreen();
      default:
        return const DiscoveryScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);
    final selectedProfileId = ref.watch(selectedProfileProvider);

    // Get current profile name
    String profileName = 'Profile';
    profiles.whenData((profileList) {
      final current = profileList
          .where((p) => p.id == selectedProfileId)
          .firstOrNull;
      if (current != null) {
        profileName = current.name;
      }
    });

    return Scaffold(
      body: Row(
        children: [
          // Side Navigation Rail
          _SideNavRail(
            selectedIndex: _selectedIndex,
            items: _navItems,
            onItemSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            profileName: profileName,
            onChangeProfile: () async {
              await ref.read(selectedProfileProvider.notifier).clear();
            },
            onLogout: () async {
              await ref.read(authProvider.notifier).logout();
            },
          ),
          // Vertical Divider
          VerticalDivider(width: 1, thickness: 1, color: Colors.grey.shade800),
          // Main Content
          Expanded(child: _buildScreen()),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _SideNavRail extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onItemSelected;
  final String profileName;
  final VoidCallback onChangeProfile;
  final VoidCallback onLogout;

  const _SideNavRail({
    required this.selectedIndex,
    required this.items,
    required this.onItemSelected,
    required this.profileName,
    required this.onChangeProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      color: Colors.grey.shade900,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // App Logo/Title
          Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.water_drop,
              size: 32,
              color: Colors.deepPurple.shade300,
            ),
          ),

          const SizedBox(height: 24),

          // Navigation Items
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;

                return _NavButton(
                  icon: isSelected ? item.selectedIcon : item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  onTap: () => onItemSelected(index),
                );
              },
            ),
          ),

          // Profile Menu at Bottom
          PopupMenuButton<String>(
            offset: const Offset(80, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(Icons.account_circle, size: 32),
                  const SizedBox(height: 4),
                  Text(
                    profileName,
                    style: const TextStyle(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            onSelected: (value) {
              if (value == 'change_profile') {
                onChangeProfile();
              } else if (value == 'logout') {
                onLogout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'change_profile',
                child: Row(
                  children: [
                    Icon(Icons.switch_account),
                    SizedBox(width: 12),
                    Text('Change Profile'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected
        ? Colors.deepPurple.shade300
        : _isHovered
        ? Colors.white
        : Colors.grey.shade500;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: widget.isSelected
                ? Border(
                    left: BorderSide(
                      color: Colors.deepPurple.shade300,
                      width: 3,
                    ),
                  )
                : null,
          ),
          child: Column(
            children: [
              Icon(widget.icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(widget.label, style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
