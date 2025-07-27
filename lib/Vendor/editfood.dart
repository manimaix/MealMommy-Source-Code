import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/meal_model.dart';

class EditFoodPage extends StatefulWidget {
  final Meal meal;
  const EditFoodPage({super.key, required this.meal});

  @override
  State<EditFoodPage> createState() => _EditFoodPageState();
}

class _EditFoodPageState extends State<EditFoodPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  int _completedStep = -1;

  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController quantityController;
  late TextEditingController priceController;
  late TextEditingController allergensController;

  late bool isOvercooked;
  late bool status;
  File? _pickedImage;

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

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.meal.name);
    descriptionController = TextEditingController(text: widget.meal.description);
    quantityController = TextEditingController(text: widget.meal.quantityAvailable.toString());
    priceController = TextEditingController(text: widget.meal.price.toString());
    allergensController = TextEditingController(text: widget.meal.allergens);
    selectedTags = widget.meal.allergens.split(', ').toList();
    isOvercooked = widget.meal.isOvercooked;
    status = widget.meal.status;
  }

  Future<void> _updateFood() async {
    if (_formKey.currentState!.validate()) {
      final mealId = widget.meal.mealId;

      final updatedData = {
        'name': nameController.text.trim(),
        'description': descriptionController.text.trim(),
        'quantity_available': int.tryParse(quantityController.text.trim()) ?? 0,
        'price': double.tryParse(priceController.text.trim()) ?? 0.0,
        'is_overcooked': isOvercooked,
        'status': status,
        'allergens': selectedTags.join(', ')
      };

    if (status) {
      updatedData['expired_date'] = Timestamp.now();
    }
    
      await FirebaseFirestore.instance.collection('meals').doc(mealId).update(updatedData);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Food")),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 2) {
              setState(() {
                _completedStep = _currentStep;
                _currentStep++;
              });
            } else {
              _updateFood();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            }
          },
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 2;
            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: details.onStepContinue,
                  child: Text(isLastStep ? 'Update' : 'Next'),
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
              title: const Text('Meal Info'),
              content: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        setState(() => _pickedImage = File(picked.path));
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
                            ? Image.file(_pickedImage!, fit: BoxFit.cover)
                            : Image.network(widget.meal.imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Meal Name
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Meal Name",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameController,
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
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),

                  // Description
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Description",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: descriptionController,
                    decoration: InputDecoration(
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
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
              isActive: _currentStep >= 0,
              state: _completedStep >= 0 ? StepState.complete : StepState.indexed,
            ),

            Step(
              title: const Text('Dietary & Allergen'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Dietary Tags
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
                    children: dietaryTags.map((tag) {
                      return FilterChip(
                        label: Text(tag),
                        selected: selectedTags.contains(tag),
                        onSelected: (val) {
                          setState(() {
                            val ? selectedTags.add(tag) : selectedTags.remove(tag);
                            allergensController.text = selectedTags.join(', ');
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Allergen Tags
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
                    children: allergenTags.map((tag) {
                      return FilterChip(
                        label: Text(tag),
                        selected: selectedTags.contains(tag),
                        onSelected: (val) {
                          setState(() {
                            val ? selectedTags.add(tag) : selectedTags.remove(tag);
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
              isActive: _currentStep >= 1,
              state: _completedStep >= 1 ? StepState.complete : StepState.indexed,
            ),

            Step(
              title: const Text('Price & Menu Setup'),
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
                  // Quantity
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
                      onChanged: (val) {
                        final qty = int.tryParse(val) ?? 0;
                        if (qty == 0 && status == true) {
                          setState(() {
                            status = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Food status is uavailable when quantity is 0.")),
                          );
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter quantity';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 16),

                  // Price
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Price",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 8),
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

                  // Is Overcooked
                  SwitchListTile(
                    title: const Text('Is Overcooked'),
                    value: isOvercooked,
                    onChanged: (val) {
                      setState(() {
                        isOvercooked = val;
                      });
                    },
                  ),

                  // Status
                  SwitchListTile(
                    title: const Text('Status (Available)'),
                    value: status,
                    onChanged: (val) {
                      final qty = int.tryParse(quantityController.text) ?? 0;
                      if (qty == 0 && val == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Food status is uavailable when quantity is 0.")),
                        );
                        return;
                      }
                      setState(() {
                        status = val;
                      });
                    },
                  ),
                ],
              ),
              isActive: _currentStep >= 2,
              state: _completedStep >= 2 ? StepState.complete : StepState.indexed,
            ),
          ],
        ),
      ),
    );
  }
}
