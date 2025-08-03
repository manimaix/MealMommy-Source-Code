import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// A profile page that can display and optionally edit a user's profile.
/// If [uid] is omitted, shows the current user's profile.
class UserProfilePage extends StatefulWidget {
  final String? uid;
  final bool editable;

  const UserProfilePage({Key? key, this.uid, this.editable = true}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String _email = '';
  String _role = '';
  String? _profileImage;
  bool _loading = true;

  // Delivery Preference fields (for drivers)
  double _maxDistance = 0.0;
  String _transportMode = 'bicycle';
  final List<String> _transportOptions = ['bicycle', 'motorcycle', 'car', 'van'];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final userId = widget.uid ?? _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!mounted) return;
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone_number'] ?? '';
        _addressController.text = data['address'] ?? '';
        _email = data['email'] ?? '';
        _role = data['role'] ?? '';
        _profileImage = data['profile_image'] ?? '';

        // If driver, load delivery preferences
        if (_role.toLowerCase() == 'driver' || _role.toLowerCase() == 'runner') {
          final prefDoc = await _firestore.collection('deliverypreference').doc(userId).get();
          if (prefDoc.exists) {
            final pref = prefDoc.data()!;
            _maxDistance = (pref['max_distance'] ?? 0).toDouble();
            _transportMode = pref['transport_mode'] ?? _transportMode;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!widget.editable) return;
    final userId = widget.uid ?? _auth.currentUser?.uid;
    if (userId == null) return;

    final batch = _firestore.batch();
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'name': _nameController.text,
      'phone_number': _phoneController.text,
      'address': _addressController.text,
    });

    if (_role.toLowerCase() == 'driver' || _role.toLowerCase() == 'runner') {
      final prefRef = _firestore.collection('deliverypreference').doc(userId);
      batch.set(prefRef, {
        'runnerid': userId,
        'max_distance': _maxDistance,
        'transport_mode': _transportMode,
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile.')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editable ? 'Edit Profile' : 'View Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: (_profileImage != null && _profileImage!.isNotEmpty)
                              ? NetworkImage(_profileImage!)
                              : null,
                          child: (_profileImage == null || _profileImage!.isEmpty)
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _role,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTextField(
                    label: 'Name',
                    controller: _nameController,
                    readOnly: !widget.editable,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Email',
                    initialValue: _email,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    readOnly: !widget.editable,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Address',
                    controller: _addressController,
                    readOnly: !widget.editable,
                  ),

                  // Delivery preferences for drivers/runners
                  if ((_role.toLowerCase() == 'driver' || _role.toLowerCase() == 'runner') && widget.editable) ...[
                    const Divider(height: 32),
                    Text('Max Distance (km): ${_maxDistance.toStringAsFixed(1)}'),
                    Slider(
                      min: 0,
                      max: 20,
                      divisions: 100,
                      label: _maxDistance.toStringAsFixed(1),
                      value: _maxDistance,
                      onChanged: (val) => setState(() => _maxDistance = val),
                    ),
                    const SizedBox(height: 16),
                    const Text('Transport Mode'),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _transportMode,
                      items: _transportOptions
                          .map((mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(mode[0].toUpperCase() + mode.substring(1)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _transportMode = val);
                      },
                    ),
                  ],

                  if (widget.editable) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      decoration: InputDecoration(labelText: label),
      readOnly: readOnly,
      keyboardType: keyboardType,
    );
  }
}
