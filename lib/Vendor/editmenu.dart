import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/meal_model.dart';

class EditMenuPage extends StatefulWidget {
  final Meal meal;
  const EditMenuPage({super.key, required this.meal});

  @override
  State<EditMenuPage> createState() => _EditMenuPageState();
}

class _EditMenuPageState extends State<EditMenuPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  int _completedStep = -1;
  late TextEditingController quantityController;
  late bool isOvercooked;
  late bool status;

  @override
  void initState() {
    super.initState();
    quantityController = TextEditingController(text: widget.meal.quantityAvailable.toString());
    isOvercooked = widget.meal.isOvercooked;
    status = widget.meal.status;
  }

  Future<void> _updateMenu() async {
    if (_formKey.currentState!.validate()) {
      final qty = int.tryParse(quantityController.text) ?? 0;

      final updateData = {
        'quantity_available': qty,
        'is_overcooked': isOvercooked,
        'status': status,
      };

      if (status) {
        updateData['expired_date'] = Timestamp.now();
      }

      await FirebaseFirestore.instance
        .collection('meals')
        .doc(widget.meal.mealId)
        .update(updateData);

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Menu")
      , centerTitle: true),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 1) {
                setState(() {
                  _completedStep = _currentStep;
                  _currentStep++;
                });
              } else {
                _updateMenu();
              }
            },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            }
          },
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 1;
            return Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(isLastStep ? 'Update' : 'Next'),
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
              title: const Text('Meal Info'),
              content: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(widget.meal.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
                ),
                title: Text(widget.meal.name),
                subtitle: Text("RM${widget.meal.price.toStringAsFixed(2)}"),
              ),
              isActive: _currentStep >= 0,
              state: _completedStep >= 0 ? StepState.complete : StepState.indexed,
            ),
            
            Step(
              title: const Text('Update Menu'),
              content: Column(
                children: [
                  TextFormField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      hintText: 'Enter quantity',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final qty = int.tryParse(value ?? '');
                      if (qty == null || qty <= 0) return 'Enter valid quantity';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Is Overcooked'),
                    value: isOvercooked,
                    onChanged: (val) => setState(() => isOvercooked = val),
                  ),
                  SwitchListTile(
                    title: const Text('Available Status'),
                    value: status,
                    onChanged: (val) => setState(() => status = val),
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
