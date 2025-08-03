import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  String? _qrCodeImage;
  File? _selectedQrCodeFile;
  bool _loading = true;
  bool _uploadingQrCode = false;

  final ImagePicker _imagePicker = ImagePicker();

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
        _qrCodeImage = data['qr_code'];

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
    
    Map<String, dynamic> updateData = {
      'name': _nameController.text,
      'phone_number': _phoneController.text,
      'address': _addressController.text,
    };

    // Upload QR code image if selected
    if (_selectedQrCodeFile != null) {
      setState(() => _uploadingQrCode = true);
      try {
        final qrCodeUrl = await _uploadQrCodeImage(userId);
        if (qrCodeUrl != null) {
          updateData['qr_code'] = qrCodeUrl;
          setState(() => _qrCodeImage = qrCodeUrl);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload QR code: $e')),
        );
      } finally {
        setState(() => _uploadingQrCode = false);
      }
    }

    batch.update(userRef, updateData);

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
      setState(() => _selectedQrCodeFile = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile.')),
      );
    }
  }

  Future<String?> _uploadQrCodeImage(String userId) async {
    if (_selectedQrCodeFile == null) return null;
    
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('qr_codes')
          .child('$userId.jpg');
      
      final uploadTask = storageRef.putFile(_selectedQrCodeFile!);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading QR code: $e');
      return null;
    }
  }

  Future<void> _pickQrCodeImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedQrCodeFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  void _removeSelectedQrCode() {
    setState(() {
      _selectedQrCodeFile = null;
    });
  }

  void _handleBackNavigation(BuildContext context) {
    // Check if we can pop (meaning there's a previous route)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // If we can't pop, navigate to the appropriate home page based on role
      switch (_role.toLowerCase()) {
        case 'vendor':
          Navigator.of(context).pushReplacementNamed('/vendor');
          break;
        case 'driver':
        case 'runner':
          Navigator.of(context).pushReplacementNamed('/driver');
          break;
        case 'customer':
        default:
          Navigator.of(context).pushReplacementNamed('/customer');
          break;
      }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handleBackNavigation(context),
        ),
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

                  // QR Code section for drivers and vendors
                  if ((_role.toLowerCase() == 'driver' || _role.toLowerCase() == 'runner' || _role.toLowerCase() == 'vendor') && widget.editable) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    _buildQrCodeSection(),
                  ],

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

  Widget _buildQrCodeSection() {
    final String qrTitle = _role.toLowerCase() == 'vendor' ? 'Vendor QR Code' : 'Driver QR Code';
    final String qrDescription = _role.toLowerCase() == 'vendor' 
        ? 'Upload your vendor QR code for customer payments'
        : 'Upload your driver QR code for verification';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.qr_code, size: 24),
            const SizedBox(width: 8),
            Text(
              qrTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Current QR Code Display
        if (_qrCodeImage != null || _selectedQrCodeFile != null) ...[
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _selectedQrCodeFile != null
                  ? Image.file(
                      _selectedQrCodeFile!,
                      fit: BoxFit.contain,
                    )
                  : Image.network(
                      _qrCodeImage!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 40, color: Colors.red),
                              Text('Failed to load QR code'),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // No QR Code Placeholder
        if (_qrCodeImage == null && _selectedQrCodeFile == null) ...[
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2, size: 50, color: Colors.grey),
                const SizedBox(height: 8),
                const Text(
                  'No QR Code uploaded',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  qrDescription,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _uploadingQrCode ? null : _pickQrCodeImage,
                icon: _uploadingQrCode 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt),
                label: Text(_uploadingQrCode ? 'Uploading...' : 'Select QR Code'),
              ),
            ),
            if (_selectedQrCodeFile != null) ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _removeSelectedQrCode,
                icon: const Icon(Icons.clear),
                label: const Text('Remove'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  foregroundColor: Colors.red[800],
                ),
              ),
            ],
          ],
        ),
        
        if (_selectedQrCodeFile != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'New QR code selected. Click "Save Changes" to upload.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
