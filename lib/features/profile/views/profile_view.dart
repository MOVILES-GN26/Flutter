import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/cache/image_cache_manager.dart';
import 'package:provider/provider.dart';
import '../../../core/models/listing.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../catalog/views/product_detail_view.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'settings_view.dart';

const _kOlive = Color(0xFF8B7E3B);
const _kOliveBorder = Color(0xFFD4C84A);

/// Profile screen – displays user info and their marketplace listings.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      final authUser = context.read<AuthViewModel>().user;
      context.read<ProfileViewModel>().loadProfile(authUser: authUser);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Color(0xFF1C1A0D)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsView()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(
            message:
                'Offline · profile from cache · your listings may not be up to date',
          ),
          Expanded(
            child: Consumer<ProfileViewModel>(
              builder: (context, vm, _) {
          if (vm.status == ProfileStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(color: _kOliveBorder),
            );
          }

          if (vm.status == ProfileStatus.error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: _kOlive),
                  const SizedBox(height: 12),
                  Text(
                    vm.errorMessage ?? 'Something went wrong.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final authUser = context.read<AuthViewModel>().user;
                      vm.loadProfile(authUser: authUser);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOliveBorder,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: _kOliveBorder,
            onRefresh: () async {
              final authUser = context.read<AuthViewModel>().user;
              await vm.loadProfile(authUser: authUser);
            },
            child: CustomScrollView(
              slivers: [
                // ── User info header ──
                SliverToBoxAdapter(child: _UserHeader(vm: vm)),

                // ── Personal Info ──
                SliverToBoxAdapter(child: _PersonalInfoSection(vm: vm)),

                // ── My Listings header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    child: Text(
                      'My Listings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),

                // ── Listings grid ──
                if (vm.listings.isEmpty &&
                    vm.status == ProfileStatus.loaded)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 32),
                      child: Center(
                        child: Text(
                          "You haven't posted any listings yet.",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = vm.listings[index];
                          return _ListingCard(
                            item: item,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailView(item: item),
                              ),
                            ),
                          );
                        },
                        childCount: vm.listings.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// User header: avatar + name + major
// ─────────────────────────────────────────────
class _UserHeader extends StatelessWidget {
  final ProfileViewModel vm;
  const _UserHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(
        children: [
          // Avatar circle
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF5ECCF),
              border: Border.all(
                color: _kOliveBorder.withAlpha(80),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: vm.avatarUrl != null && vm.avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      cacheManager: AndesHubImageCacheManager.instance,
                      imageUrl: vm.avatarUrl!,
                      fit: BoxFit.cover,
                      width: 90,
                      height: 90,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _kOliveBorder),
                      ),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.person, size: 54, color: _kOlive),
                    )
                  : const Icon(Icons.person, size: 54, color: _kOlive),
            ),
          ),
          const SizedBox(height: 14),
          // Name
          Text(
            vm.name?.isNotEmpty == true ? vm.name! : '—',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          // Major
          if (vm.major?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              vm.major!,
              style: const TextStyle(
                fontSize: 13,
                color: _kOlive,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Personal Info section
// ─────────────────────────────────────────────
class _PersonalInfoSection extends StatelessWidget {
  final ProfileViewModel vm;
  const _PersonalInfoSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Info',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // Email tile
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: vm.email ?? '—',
          ),

          // Phone tile
          if (vm.phoneNumber?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: vm.phoneNumber!,
            ),
          ],

          // Student ID tile (only when the JWT provides it)
          if (vm.studentId?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _InfoTile(
              icon: Icons.badge_outlined,
              label: 'Student ID',
              value: vm.studentId!,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reusable info tile (email / student ID)
// ─────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Individual listing card in the 2-column grid
// ─────────────────────────────────────────────
class _ListingCard extends StatelessWidget {
  final Listing item;
  final VoidCallback onTap;

  const _ListingCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product image
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                color: const Color(0xFFF5ECCF),
                child: item.imageUrls.isNotEmpty
                    ? CachedNetworkImage(
                        cacheManager: AndesHubImageCacheManager.instance,
                        imageUrl: item.imageUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kOliveBorder,
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 36,
                            color: _kOlive,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 36,
                          color: _kOlive,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Title
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
