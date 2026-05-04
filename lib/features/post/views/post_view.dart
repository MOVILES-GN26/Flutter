import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/post_categories.dart';
import '../../../core/constants/post_conditions.dart';
import '../../../core/constants/uniandes_buildings.dart';
import '../../../core/widgets/offline_banner.dart';
import '../viewmodels/post_viewmodel.dart';

/// Post an Item screen matching the Figma design.
class PostView extends StatefulWidget {
  const PostView({super.key});

  @override
  State<PostView> createState() => _PostViewState();
}

class _PostViewState extends State<PostView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _selectedCategory;
  String? _selectedBuilding;
  String? _selectedCondition;

  // References to the internal controllers owned by the Autocomplete widgets.
  // Captured in fieldViewBuilder so we can programmatically set text on restore.
  TextEditingController? _categoryController;
  TextEditingController? _buildingController;

  // Whether we already offered to restore the draft this session.
  bool _draftOfferShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<PostViewModel>();
      vm.loadStores();
      vm.startBatteryMonitor();
      if (vm.hasDraft && !_draftOfferShown) {
        _draftOfferShown = true;
        _showDraftRestoreBanner(vm);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    // Read without listening — safe in dispose.
    context.read<PostViewModel>().stopBatteryMonitor();
    super.dispose();
  }

  /// Shows a bottom-sheet banner letting the user restore the saved draft.
  void _showDraftRestoreBanner(PostViewModel vm) {
    final draft = vm.savedDraft;
    final savedAt = draft['savedAt'];
    final timeLabel = savedAt != null
        ? _formatDraftTime(DateTime.tryParse(savedAt))
        : 'previously';

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.battery_alert, color: Color(0xFF8B7E3B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Draft saved $timeLabel',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your battery was low while you were filling out a post. '
              'Would you like to restore your progress?',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      vm.clearDraft();
                    },
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _applyDraft(draft);
                    },
                    child: const Text('Restore'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDraftTime(DateTime? dt) {
    if (dt == null) return 'previously';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Fills every form field with the values from [draft].
  void _applyDraft(Map<String, String?> draft) {
    _titleController.text = draft['title'] ?? '';
    _descriptionController.text = draft['description'] ?? '';
    _priceController.text = draft['price'] ?? '';
    // Autocomplete controllers are captured lazily — if they are already
    // mounted (post frame), set them directly; otherwise schedule it.
    void applyAutoComplete() {
      _categoryController?.text = draft['category'] ?? '';
      _buildingController?.text = draft['building'] ?? '';
    }
    setState(() {
      _selectedCategory = draft['category'];
      _selectedBuilding = draft['building'];
      _selectedCondition = draft['condition'];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => applyAutoComplete());
    // Also update ViewModel mirrors so the draft immediately reflects current form.
    context.read<PostViewModel>().notifyFormState(
          title: draft['title'] ?? '',
          description: draft['description'] ?? '',
          category: draft['category'] ?? '',
          building: draft['building'] ?? '',
          price: draft['price'] ?? '',
          condition: draft['condition'] ?? '',
        );
  }

  void _handlePublish(PostViewModel vm) {
    if (_formKey.currentState!.validate()) {
      if (vm.images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one photo')),
        );
        return;
      }
      if (_selectedCondition == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a condition')),
        );
        return;
      }
      vm.createPost(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        buildingLocation: _selectedBuilding!,
        price: double.parse(_priceController.text.trim()),
        condition: _selectedCondition!,
      );
    }
  }

  void _showImageSourceSheet(PostViewModel vm) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                vm.pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                vm.pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostViewModel>(
      builder: (context, vm, _) {
        // On success, show confirmation and reset
        if (vm.status == PostStatus.success) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _titleController.clear();
            _descriptionController.clear();
            _priceController.clear();
            setState(() {
              _selectedCategory = null;
              _selectedBuilding = null;
              _selectedCondition = null;
            });
            vm.reset();
            Navigator.pop(context, true);
          });
        }

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () {
                // If in a navigation context we can pop, otherwise do nothing
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                }
              },
            ),
            centerTitle: true,
            title: Text(
              'Post an Item',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                const OfflineBanner(
                  message:
                      "Offline · we'll publish your item when you reconnect",
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                    // ── Photos section ──
                    const Text(
                      'Photos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (vm.images.isEmpty)
                      GestureDetector(
                        onTap: () => _showImageSourceSheet(vm),
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5ECCF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE8E5D1),
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined,
                                  size: 44, color: Color(0xFF8B7E3B)),
                              SizedBox(height: 10),
                              Text(
                                'Tap to add a photo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF8B7E3B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              vm.images.first,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => vm.removeImage(0),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.close,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),

                    // ── Details section ──
                    const Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Title
                    TextFormField(
                      controller: _titleController,
                      maxLength: 50,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (v) =>
                          context.read<PostViewModel>().notifyFormState(title: v),
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(
                          RegExp(r'[\u{1F000}-\u{1FFFF}]|[\u{2600}-\u{27BF}]|[\u{FE00}-\u{FE0F}]', unicode: true),
                        ),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        counterText: '',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Title is required';
                        }
                        if (v.trim().length < 3) {
                          return 'Must be at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLength: 200,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (v) => context
                          .read<PostViewModel>()
                          .notifyFormState(description: v),
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(
                          RegExp(r'[\u{1F000}-\u{1FFFF}]|[\u{2600}-\u{27BF}]|[\u{FE00}-\u{FE0F}]', unicode: true),
                        ),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Description',
                        counterText: '',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Description is required';
                        }
                        if (v.trim().length < 10) {
                          return 'Must be at least 10 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category — Autocomplete (consistent with Building)
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return postCategories;
                        }
                        return postCategories.where(
                          (c) => c.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              ),
                        );
                      },
                      onSelected: (v) =>
                          setState(() => _selectedCategory = v),
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                        _categoryController = controller; // capture for draft restore
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLength: 50,
                          onChanged: (v) => context
                              .read<PostViewModel>()
                              .notifyFormState(category: v),
                          decoration: InputDecoration(
                            counterText: '',
                            suffixIcon: Icon(Icons.arrow_drop_down,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please select or enter a category';
                            }
                            if (v.trim().length < 2) {
                              return 'Must be at least 2 characters';
                            }
                            _selectedCategory = v.trim();
                            return null;
                          },
                          onFieldSubmitted: (_) => onSubmitted(),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 200,
                                maxWidth: 340,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return InkWell(
                                    onTap: () => onSelected(option),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Text(
                                        option,
                                        style:
                                            const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Condition
                    const Text(
                      'Condition',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF96914F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: conditionOptions.map((opt) {
                        final isSelected = _selectedCondition == opt;
                        return GestureDetector(
                          onTap: () {
                            final next = isSelected ? null : opt;
                            setState(() => _selectedCondition = next);
                            context
                                .read<PostViewModel>()
                                .notifyFormState(condition: next ?? '');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFF5ECCF)
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFD4C84A)
                                    : Theme.of(context).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Text(
                              opt,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF8B7E3B)
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Building location — Autocomplete (same pattern as majors)
                    Autocomplete<String>(
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return uniAndesBuildings;
                        }
                        return uniAndesBuildings.where(
                          (b) => b.toLowerCase().contains(
                                textEditingValue.text.toLowerCase(),
                              ),
                        );
                      },
                      onSelected: (v) =>
                          setState(() => _selectedBuilding = v),
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                        _buildingController = controller; // capture for draft restore
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLength: 120,
                          onChanged: (v) => context
                              .read<PostViewModel>()
                              .notifyFormState(building: v),
                          decoration: InputDecoration(
                            hintText: 'Building Location',
                            counterText: '',
                            suffixIcon: Icon(Icons.arrow_drop_down,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please select a location';
                            }
                            if (!uniAndesBuildings.contains(v.trim())) {
                              return 'Please select a valid building from the list';
                            }
                            _selectedBuilding = v.trim();
                            return null;
                          },
                          onFieldSubmitted: (_) => onSubmitted(),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 200,
                                maxWidth: 340,
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return InkWell(
                                    onTap: () => onSelected(option),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Text(
                                        option,
                                        style:
                                            const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Price
                    TextFormField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      maxLength: 12,
                      onChanged: (v) =>
                          context.read<PostViewModel>().notifyFormState(price: v),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Price (COP)',
                        counterText: '',
                        prefixText: '\$ ',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Price is required';
                        }
                        final price = double.tryParse(v.trim());
                        if (price == null || price <= 0) {
                          return 'Enter a valid price greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Post as
                    const Text(
                      'Post as',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF96914F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: vm.selectedStoreId,
                          dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          icon: Icon(Icons.arrow_drop_down,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                          onChanged: (value) => vm.selectStore(value),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline,
                                      size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                  const SizedBox(width: 10),
                                  const Text('Personal Profile',
                                      style: TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                            ...vm.stores.map(
                              (store) => DropdownMenuItem<String?>(
                                value: store['id'] as String,
                                child: Row(
                                  children: [
                                    Icon(Icons.storefront_outlined,
                                        size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        store['name'] as String,
                                        style:
                                            const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error message
                    if (vm.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          vm.errorMessage!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 14),
                        ),
                      ),

                    // Publish button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: vm.status == PostStatus.loading
                            ? null
                            : () => _handlePublish(vm),
                        child: vm.status == PostStatus.loading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              )
                            : const Text('Publish'),
                      ),
                    ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
