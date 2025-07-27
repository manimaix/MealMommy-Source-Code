import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddMenuPage extends StatefulWidget {
  const AddMenuPage({super.key});

  @override
  State<AddMenuPage> createState() => _AddMenuPageState();
}

class _AddMenuPageState extends State<AddMenuPage> {
  int _completedStep = -1;
  int _currentStep = 0;
  String? selectedMealId;
  String? selectedMealName;

  final _formKey = GlobalKey<FormState>();
  final quantityController = TextEditingController();
  bool isOvercooked = false;
  bool status = false;

  Future<void> _submitMenu() async {
    if (_formKey.currentState!.validate() && selectedMealId != null) {
      final qty = int.tryParse(quantityController.text) ?? 0;

      final updateData = {
        'quantity_available': qty,
        'is_overcooked': isOvercooked,
        'status': true,
      };
      
      if (status) {
        updateData['expired_date'] = Timestamp.now();
      }

      await FirebaseFirestore.instance
          .collection('meals')
          .doc(selectedMealId)
          .update(updateData);

      Navigator.pop(context);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add to Menu"), centerTitle: true),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 1) {
              if (selectedMealId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please select a meal.")),
                );
                return;
              }
              _completedStep = _currentStep;
              setState(() => _currentStep++);
            } else {
              _submitMenu();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 1;
            return Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(isLastStep ? 'Submit' : 'Next'),
                ),
                const SizedBox(width: 8),
                if (_currentStep > 0)
                  ElevatedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            );
          },
          steps: [
            Step(
              title: const Text('Select Meal'),
              content: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('meals')
                .where('status', isEqualTo: false)
                .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text("No meals found.");
                  }

                  final meals = snapshot.data!.docs;
                  return Column(
                    children: meals.map((doc) {
                      final name = doc['name'];
                      return RadioListTile<String>(
                        title: Text(name),
                        value: doc.id,
                        groupValue: selectedMealId,
                        onChanged: (value) {
                          setState(() {
                            selectedMealId = value;
                            selectedMealName = name;
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
              isActive: _currentStep >= 0,
              state: _completedStep >= 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Setup Menu'),
              content: Column(
                children: [
                  TextFormField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      hintText: 'Enter quantity',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      final qty = int.tryParse(val) ?? 0;
                      if (qty == 0 && status == false) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Status cannot be available when quantity is 0.")),
                        );
                      }
                    },
                    validator: (value) {
                    final qty = int.tryParse(value ?? '');
                    if (qty == null) return 'Quantity is required';
                    if (qty <= 0) return 'Quantity cannot be 0';
                    return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Is Overcooked'),
                    value: isOvercooked,
                    onChanged: (val) {
                      setState(() => isOvercooked = val);
                    },
                  ),
                ],
              ),
              isActive: _currentStep >= 1,
              state: _completedStep >= 1 ? StepState.complete : StepState.indexed,
            ),
          ],
        ),
      ),
    );
  }
}
