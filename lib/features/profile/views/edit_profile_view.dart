import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/uniandes_majors.dart';
import '../viewmodels/profile_viewmodel.dart';

const _kBackground = Color(0xFFFCFAF7);
const _kCardBg = Color(0xFFF2F2E8);
const _kOlive = Color(0xFF8B7E3B);
const _kYellow = Color(0xFFD4C84A);

/// Edit Profile screen – lets the user update name, major, password and avatar.
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _confirmPasswordCtrl;

  String? _selectedMajor;
  File? _pickedImage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final vm = context.read<ProfileViewModel>();
    _firstNameCtrl = TextEditingController(text: vm.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: vm.lastName ?? '');
    _phoneCtrl = TextEditingController(text: vm.phoneNumber ?? '');
    _passwordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    _selectedMajor = vm.major;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (file != null) {
      setState(() => _pickedImage = File(file.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordCtrl.text.trim();
    final confirm = _confirmPasswordCtrl.text.trim();
    if (password.isNotEmpty && password != confirm) {
      _showSnackBar('Passwords do not match.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final vm = context.read<ProfileViewModel>();
    bool allOk = true;

    // Upload avatar first if changed
    if (_pickedImage != null) {
      final avatarOk = await vm.updateAvatar(_pickedImage!);
      if (!avatarOk) {
        allOk = false;
        _showSnackBar('Failed to upload photo. Other changes will still be saved.', isError: true);
      }
    }

    // Update profile fields
    final profileOk = await vm.updateProfile(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      major: _selectedMajor ?? (vm.major ?? ''),
      password: password.isNotEmpty ? password : null,
      phoneNumber: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
    );

    if (!profileOk) allOk = false;

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (allOk) {
      _showSnackBar('Profile updated successfully.');
      Navigator.pop(context);
    } else {
      _showSnackBar('Some changes could not be saved. Please try again.', isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : _kOlive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

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
          'Edit Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C1A0D),
          ),
        ),
      ),
      body: Consumer<ProfileViewModel>(
        builder: (context, vm, _) {
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  // ── Avatar ──
                  _buildAvatar(vm),
                  const SizedBox(height: 32),

                  // ── First Name ──
                  _FieldLabel(label: 'First_Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _firstNameCtrl,
                    hint: 'First name',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter your first name'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Last Name ──
                  _FieldLabel(label: 'Last_Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _lastNameCtrl,
                    hint: 'Last name',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter your last name'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Phone Number ──
                  _FieldLabel(label: 'Phone Number'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 10,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF1C1A0D)),
                    decoration: InputDecoration(
                      hintText: 'Phone number (10 digits)',
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                      counterText: '',
                      filled: true,
                      fillColor: _kCardBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kYellow, width: 1.5)),
                      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent, width: 1)),
                      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length != 10) {
                        return 'Must be exactly 10 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Major dropdown ──
                  _buildMajorDropdown(),
                  const SizedBox(height: 20),

                  // ── New Password ──
                  _FieldLabel(label: 'New Password (optional)'),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    controller: _passwordCtrl,
                    hint: 'Enter new password',
                    obscure: _obscurePassword,
                    onToggle: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  const SizedBox(height: 20),

                  // ── Confirm Password ──
                  _FieldLabel(label: 'Confirm Password'),
                  const SizedBox(height: 8),
                  _buildPasswordField(
                    controller: _confirmPasswordCtrl,
                    hint: 'Confirm new password',
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    validator: (v) {
                      final pwd = _passwordCtrl.text.trim();
                      if (pwd.isNotEmpty && v != pwd) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 36),

                  // ── Update button ──
                  _buildUpdateButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Avatar circle with camera overlay
  // ─────────────────────────────────────────────
  Widget _buildAvatar(ProfileViewModel vm) {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kCardBg,
                border: Border.all(color: _kYellow.withAlpha(100), width: 2),
              ),
              child: ClipOval(
                child: _pickedImage != null
                    ? Image.file(_pickedImage!, fit: BoxFit.cover)
                    : (vm.avatarUrl?.isNotEmpty == true
                        ? Image.network(vm.avatarUrl!, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.person, size: 52, color: _kOlive))
                        : const Icon(Icons.person, size: 52, color: _kOlive)),
              ),
            ),
            // Camera badge overlay
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withAlpha(50),
              ),
              child: const Icon(Icons.camera_alt_outlined,
                  size: 28, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1C1A0D)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        filled: true,
        fillColor: _kCardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kYellow, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1C1A0D)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        filled: true,
        fillColor: _kCardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.black38,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kYellow, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  Widget _buildMajorDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.transparent),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              value: _selectedMajor,
              isExpanded: true,
              hint: const Text(
                'Select major',
                style: TextStyle(color: Colors.black38, fontSize: 14),
              ),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.black38),
              decoration: const InputDecoration(
                labelText: 'Major',
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              items: uniAndesMajors
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1C1A0D))),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedMajor = v),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Please select your major'
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kYellow,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _kYellow.withAlpha(120),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Update',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Small field label above each input
// ─────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1C1A0D),
      ),
    );
  }
}
