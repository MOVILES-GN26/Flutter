import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/listing.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../auth/views/login_view.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'edit_profile_view.dart';

const _kBackground = Color(0xFFFCFAF7);
const _kCardBg = Color(0xFFF2F2E8);
const _kOlive = Color(0xFF8B7E3B);
const _kYellow = Color(0xFFD4C84A);

/// Settings screen (Profile architecture – MVVM via shared ProfileViewModel).
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kBackground,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1C1A0D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1A0D),
          ),
        ),
      ),
      body: Consumer<ProfileViewModel>(
        builder: (context, vm, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      "You don't have any listings yet.",
                      style: TextStyle(color: Colors.black45, fontSize: 14),
                    ),
                  ),
                )
              else
                ...vm.listings.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ManageListingCard(
                      item: item,
                      onDelete: () =>
                          _confirmDelete(context, vm, item),
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete product',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF1C1A0D),
          ),
        ),
        content: const Text(
          'Are you sure you want to delete this product? This action cannot be undone.',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black54, fontSize: 14),
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
      ),
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
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1C1A0D),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1A0D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _kOlive,
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow)
              const Icon(Icons.chevron_right, size: 20, color: Colors.black38),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Card body ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kCardBg,
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
                          placeholder: (_, __) => const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: _kYellow,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1A0D),
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
              decoration: const BoxDecoration(
                color: _kYellow,
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
// Logout button
// ─────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            'Logout',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1A0D),
            ),
          ),
        ),
      ),
    );
  }
}
