import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../services/upload.dart'; 


Future<void> requestPermissions() async {
  if (await Permission.storage.request().isDenied) {
    // Handle permission denied
    print("Storage permission denied");
  }

  if (await Permission.photos.request().isDenied) {
    // For Android 13+
    print("Photos permission denied");
  }
}

class AddFoodPage extends StatefulWidget {
  const AddFoodPage({super.key});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  int _currentStep = 0;
  File? _pickedImage;
  final picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController();
  final priceController = TextEditingController();
  final imageUrlController = TextEditingController();
  final allergensController = TextEditingController();

  bool isOvercooked = false;
  bool status = false;

  List<String> dietaryTags = [
    'Halal',
    'Vegetarian',
    'Vegan',
    'Pork-Free',
    'Alcohol-Free',
    'Kosher',
  ];

  List<String> allergenTags = [
    'Gluten',
    'Dairy / Milk',
    'Eggs',
    'Peanuts',
    'Tree Nuts',
    'Soy',
    'Fish',
    'Shellfish',
    'Sesame',
    'Mustard',
  ];

  List<String> selectedTags = [];
  
  Future<void> _submitMeal() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_pickedImage != null) {
      final imageUrl = await uploadToFirebaseStorage(_pickedImage!);
      if (imageUrl != null) {
        imageUrlController.text = imageUrl;
        print("Meal saved successfully!");
      }
    }


      final newMeal = {
        'name': nameController.text,
        'description': descriptionController.text,
        'price': double.tryParse(priceController.text) ?? 0.0,
        'quantity_available': int.tryParse(quantityController.text) ?? 0,
        'image_URL': imageUrlController.text,
        'allergens': allergensController.text,
        'is_overcooked': isOvercooked,
        'status': status,
        'vendor_id': user.uid,
        'date_created': Timestamp.now(),
      };

      await FirebaseFirestore.instance.collection('meals').add(newMeal);
      Navigator.pop(context); // Go back to the food list
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Meal"),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() {
                _currentStep++;
              });
            } else {
                _submitMeal();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep--;
              });
            }
          },

          controlsBuilder: (BuildContext context, ControlsDetails details) {
            final isLastStep = _currentStep == 2;

          return Padding(
              padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: <Widget>[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: details.onStepContinue,
                  child: Text(isLastStep ? 'Submit' : 'Continue'),
                ),
                const SizedBox(width: 8),
                if (_currentStep > 0)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            ),
          );
          },

          steps: [
            Step(
              title: const Text('Meal Information'),
              content: Column(
                children: [
                  GestureDetector( // Image Picker
                      onTap: () async { 
                        final ImagePicker picker = ImagePicker();
                        final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

                        if (pickedFile != null) {
                          setState(() {
                            _pickedImage = File(pickedFile.path);
                          });
                        }
                      },
                    child: Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[300],
                        ),
                        child: _pickedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _pickedImage!,
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.image, size: 50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Meal Name",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextFormField(controller: nameController, 
                  decoration: InputDecoration(
                    hintText: 'Enter meal name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0), // Rounded corners
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Description",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextFormField(controller: descriptionController, 
                  decoration: InputDecoration(
                    hintText: 'Enter meal description',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0), // Rounded corners
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Dietary and Allergen'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Dietary Tags",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: dietaryTags.map((tag) {
                      return FilterChip(
                        label: Text(tag),
                        selected: selectedTags.contains(tag),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                            allergensController.text = selectedTags.join(', ');
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Allergen Tags",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: allergenTags.map((tag) {
                      return FilterChip(
                        label: Text(tag),
                        selected: selectedTags.contains(tag),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                            allergensController.text = selectedTags.join(', ');
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Selected Tags",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: allergensController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Select allergens',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Price and Setup Menu'),
              content: Column(
                children: [
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Quantity",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 8),
                    TextFormField(
                      controller: quantityController,
                      decoration: InputDecoration(
                        hintText: 'Enter food potions',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter quantity';
                        }
                        return null;
                      },
                    ),

                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Price",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  TextFormField(
                    controller: priceController,
                    decoration: InputDecoration(
                        hintText: 'Enter food price',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                      ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter price';
                      }
                      return null;
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Is Overcooked'),
                    value: isOvercooked,
                    onChanged: (val) {
                      setState(() {
                        isOvercooked = val;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Status (Available)'),
                    value: status,
                    onChanged: (val) {
                      setState(() {
                        status = val;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }  
}
