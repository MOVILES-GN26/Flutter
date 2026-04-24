import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/listing.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/viewmodels/theme_viewmodel.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/login_view.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'edit_profile_view.dart';

const _kOlive = Color(0xFF8B7E3B);

/// Settings screen (Profile architecture – MVVM via shared ProfileViewModel).
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<ProfileViewModel>(
        builder: (context, vm, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // ── Appearance ──
              const _SectionHeader(title: 'Appearance'),
              const SizedBox(height: 12),
              const _ThemePicker(),

              const SizedBox(height: 32),

              // ── Account Settings ──
              const _SectionHeader(title: 'Account Settings'),
              const SizedBox(height: 12),
              _AccountTile(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                subtitle: 'Manage your profile information',
                showArrow: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const EditProfileView()),
                  );
                },
              ),

              const SizedBox(height: 32),

              // ── Manage Listings ──
              const _SectionHeader(title: 'Manage Listings'),
              const SizedBox(height: 12),

              if (vm.listings.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      "You don't have any listings yet.",
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.45),
                          fontSize: 14),
                    ),
                  ),
                )
              else
                ...vm.listings.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ManageListingCard(
                      item: item,
                      onDelete: () => _confirmDelete(context, vm, item),
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // ── Logout button ──
              _LogoutButton(
                onTap: () async {
                  await context.read<AuthViewModel>().logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginView()),
                    (route) => false,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shows a confirmation dialog before deleting a listing.
  void _confirmDelete(
      BuildContext context, ProfileViewModel vm, Listing item) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete product',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: cs.onSurface,
            ),
          ),
          content: Text(
            'Are you sure you want to delete this product? This action cannot be undone.',
            style: TextStyle(
                fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6), fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (item.id == null) return;
                final success = await vm.deleteProduct(item.id!);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Listing deleted successfully.'
                          : 'Failed to delete listing. Please try again.',
                    ),
                    backgroundColor: success ? _kOlive : Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Account settings tile (Edit Profile, etc.)
// ─────────────────────────────────────────────
class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showArrow;

  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: cs.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Manage your profile information',
                    style: TextStyle(fontSize: 12, color: _kOlive),
                  ),
                ],
              ),
            ),
            if (showArrow)
              Icon(Icons.chevron_right,
                  size: 20,
                  color: cs.onSurface.withValues(alpha: 0.38)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Manage listing card with yellow trash button
// ─────────────────────────────────────────────
class _ManageListingCard extends StatelessWidget {
  final Listing item;
  final VoidCallback onDelete;

  const _ManageListingCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Card body ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 56,
                  height: 56,
                  color: const Color(0xFFF5ECCF),
                  child: item.imageUrls.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.imageUrls.first,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.image_outlined,
                            size: 24,
                            color: _kOlive,
                          ),
                        )
                      : const Icon(
                          Icons.image_outlined,
                          size: 24,
                          color: _kOlive,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              // Title
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              // Space for the floating trash button
              const SizedBox(width: 36),
            ],
          ),
        ),

        // ── Floating yellow trash button (top-right) ──
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 17,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Theme picker (auto / light / dark) — persisted via PreferencesService
// ─────────────────────────────────────────────
class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final themeVm = context.watch<ThemeViewModel>();
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.brightness_6_outlined,
                size: 22,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              Text(
                'Theme',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ThemeChip(
                label: 'Auto',
                icon: Icons.brightness_auto_outlined,
                value: ThemePreference.auto,
                current: themeVm.preference,
                onTap: themeVm.setPreference,
              ),
              const SizedBox(width: 8),
              _ThemeChip(
                label: 'Light',
                icon: Icons.light_mode_outlined,
                value: ThemePreference.light,
                current: themeVm.preference,
                onTap: themeVm.setPreference,
              ),
              const SizedBox(width: 8),
              _ThemeChip(
                label: 'Dark',
                icon: Icons.dark_mode_outlined,
                value: ThemePreference.dark,
                current: themeVm.preference,
                onTap: themeVm.setPreference,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final ThemePreference value;
  final ThemePreference current;
  final ValueChanged<ThemePreference> onTap;

  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = current == value;
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary : cs.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? cs.onPrimary
                    : cs.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? cs.onPrimary
                      : cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Logout button
// ─────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            'Logout',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
