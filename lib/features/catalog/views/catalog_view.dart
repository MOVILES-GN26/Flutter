import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/post_categories.dart';
import '../../../core/models/listing.dart';
import '../viewmodels/catalog_viewmodel.dart';
import 'product_detail_view.dart';


/// Catalog screen matching the Figma design with Rappi-inspired category strip.
class CatalogView extends StatefulWidget {
  const CatalogView({super.key});

  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<CatalogViewModel>();
      vm.loadProducts();
      vm.detectLocation();
      vm.loadTrending();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Opens a bottom sheet to pick one value from a list (for Sort / Condition).
  Future<String?> _showFilterSheet({
    required String title,
    required List<String> options,
    required String? currentValue,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                child: Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    if (currentValue != null)
                      TextButton(
                        onPressed: () => Navigator.pop(context, ''),
                        child: const Text('Clear',
                            style: TextStyle(color: Color(0xFF8B7E3B))),
                      ),
                  ],
                ),
              ),
              ...options.map((opt) => ListTile(
                    title: Text(opt, style: const TextStyle(fontSize: 14)),
                    trailing: currentValue == opt
                        ? const Icon(Icons.check, color: Color(0xFF8B7E3B))
                        : null,
                    onTap: () => Navigator.pop(context, opt),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Opens the "All Filters" bottom sheet with category chips, price sort,
  /// and condition — scrollable, so it never overflows.
  void _showAllFiltersSheet(CatalogViewModel vm) {
    String? tempCategory = vm.selectedCategory;
    String? tempPriceSort = vm.selectedPriceSort;
    String? tempCondition = vm.selectedCondition;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return SafeArea(
                  child: Column(
                    children: [
                      // ── Header ──
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Expanded(
                              child: Text(
                                'All Filters',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setSheetState(() {
                                  tempCategory = null;
                                  tempPriceSort = null;
                                  tempCondition = null;
                                });
                              },
                              child: const Text('Clear',
                                  style: TextStyle(
                                      color: Color(0xFF8B7E3B))),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // ── Scrollable content ──
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          children: [
                            // ─ Categories ─
                            const Text('Category',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  vm.sortedCategories.map((cat) {
                                final isSelected =
                                    tempCategory == cat;
                                return ChoiceChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setSheetState(() {
                                      tempCategory =
                                          isSelected ? null : cat;
                                    });
                                  },
                                  selectedColor:
                                      const Color(0xFFF5ECCF),
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFFD4C84A)
                                        : const Color(0xFFE8E5D1),
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF8B7E3B)
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 24),

                            // ─ Price Sort ─
                            const Text('Sort by Price',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: priceSortOptions.map((opt) {
                                final isSelected =
                                    tempPriceSort == opt;
                                return ChoiceChip(
                                  label: Text(opt),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setSheetState(() {
                                      tempPriceSort =
                                          isSelected ? null : opt;
                                    });
                                  },
                                  selectedColor:
                                      const Color(0xFFF5ECCF),
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFFD4C84A)
                                        : const Color(0xFFE8E5D1),
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF8B7E3B)
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 24),

                            // ─ Condition ─
                            const Text('Condition',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  conditionOptions.map((opt) {
                                final isSelected =
                                    tempCondition == opt;
                                return ChoiceChip(
                                  label: Text(opt),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setSheetState(() {
                                      tempCondition =
                                          isSelected ? null : opt;
                                    });
                                  },
                                  selectedColor:
                                      const Color(0xFFF5ECCF),
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFFD4C84A)
                                        : const Color(0xFFE8E5D1),
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFF8B7E3B)
                                        : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),

                      // ── Apply button ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            24, 8, 24, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                             onPressed: () {
                              Navigator.pop(context);
                              vm.applyFilters(
                                category: tempCategory,
                                priceSort: tempPriceSort,
                                condition: tempCondition,
                              );
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AndesHub'),
      ),
      body: Consumer<CatalogViewModel>(
        builder: (context, vm, _) {
          return Column(
            children: [
              // ── Search bar ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  maxLength: 50,
                  decoration: InputDecoration(
                    hintText: 'Search for items',
                    counterText: '',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF96914F)), 
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              vm.setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() {}),
                  onSubmitted: (value) => vm.setSearchQuery(value.trim()),
                ),
              ),

              // ── Filter row: filter icon + Sort + Condition ──
              Padding(
                padding:
                    const EdgeInsets.only(left: 24, right: 24, bottom: 4),
                child: Row(
                  children: [
                    // All-filters icon button
                    _FilterIconButton(
                      hasActiveFilters: vm.selectedCategory != null,
                      onTap: () => _showAllFiltersSheet(vm),
                    ),
                    const SizedBox(width: 8),
                    _FilterButton(
                      label: 'Sort',
                      isActive: vm.selectedPriceSort != null,
                      onTap: () async {
                        final result = await _showFilterSheet(
                          title: 'Sort by Price',
                          options: priceSortOptions,
                          currentValue: vm.selectedPriceSort,
                        );
                        if (result != null) {
                          vm.setPriceSort(result.isEmpty ? null : result);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterButton(
                      label: 'Condition',
                      isActive: vm.selectedCondition != null,
                      onTap: () async {
                        final result = await _showFilterSheet(
                          title: 'Condition',
                          options: conditionOptions,
                          currentValue: vm.selectedCondition,
                        );
                        if (result != null) {
                          vm.setCondition(result.isEmpty ? null : result);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ── Icon category strip (horizontal scroll) ──
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
                  itemCount: vm.sortedCategories.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final cat = vm.sortedCategories[index];
                    final icon = categoryIcons[cat] ?? Icons.category;
                    final isSelected = vm.selectedCategory == cat;
                    return _CategoryChip(
                      icon: icon,
                      label: cat.split(' ').first, // short label
                      isSelected: isSelected,
                      onTap: () => vm.setCategory(
                          isSelected ? null : cat),
                    );
                  },
                ),
              ),

              // ── Product grid ──
              Expanded(child: _buildBody(vm)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(CatalogViewModel vm) {
    if (vm.status == CatalogStatus.loading && vm.products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4C84A)),
      );
    }

    if (vm.status == CatalogStatus.error && vm.products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Color(0xFF96914F)),
              const SizedBox(height: 12),
              Text(
                vm.errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 14, color: Color(0xFF96914F)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => vm.loadProducts(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (vm.products.isEmpty) {
      return const Center(
        child: Text(
          'No items found.',
          style: TextStyle(fontSize: 14, color: Color(0xFF96914F)),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFD4C84A),
      onRefresh: () => vm.loadProducts(),
      child: CustomScrollView(
        slivers: [
          // ── "Near You" section ──
          if (vm.nearbyProducts.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 18, color: Color(0xFF8B7E3B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Near you',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8B7E3B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  itemCount: vm.nearbyProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final item = vm.nearbyProducts[index];
                    return SizedBox(
                      width: 140,
                      child: _ProductCard(
                        item: item,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailView(item: item),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                child: Text(
                  'All products',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],

          // ── Full product grid ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _ProductCard(
                    item: vm.products[index],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailView(item: vm.products[index]),
                        ),
                      );
                    },
                  );
                },
                childCount: vm.products.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter icon button (sliders icon like Rappi) ──
class _FilterIconButton extends StatelessWidget {
  final bool hasActiveFilters;
  final VoidCallback onTap;

  const _FilterIconButton({
    required this.hasActiveFilters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasActiveFilters ? const Color(0xFFF5ECCF) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasActiveFilters
                ? const Color(0xFFD4C84A)
                : const Color(0xFFE8E5D1),
          ),
        ),
        child: Icon(
          Icons.tune,
          size: 18,
          color: hasActiveFilters
              ? const Color(0xFF8B7E3B)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ── Icon category chip for the horizontal strip ──
class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF5ECCF)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFD4C84A)
                      : const Color(0xFFE8E5D1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? const Color(0xFF8B7E3B)
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFF8B7E3B)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter button widget ──
class _FilterButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF5ECCF) : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFFD4C84A)
                : const Color(0xFFE8E5D1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isActive
                    ? const Color(0xFF8B7E3B)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isActive
                  ? const Color(0xFF8B7E3B)
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual product card ──
class _ProductCard extends StatelessWidget {
  final Listing item;
  final VoidCallback onTap;

  const _ProductCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5ECCF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: item.imageUrls.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFD4C84A)),
                        ),
                        errorWidget: (_, _, _) => const Center(
                          child: Icon(Icons.image_outlined,
                              size: 36, color: Color(0xFF8B7E3B)),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.image_outlined,
                            size: 36, color: Color(0xFF8B7E3B)),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            '\$${item.price.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8B7E3B),
            ),
          ),
        ],
      ),
    );
  }
}
