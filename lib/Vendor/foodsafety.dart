import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FoodSafetyPage extends StatefulWidget {
  const FoodSafetyPage({super.key});

  @override
  State<FoodSafetyPage> createState() => _FoodSafetyPageState();
}

class _FoodSafetyPageState extends State<FoodSafetyPage> {
  final currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;
  int currentStep = 0;

  Map<String, dynamic> formState = {
    'ssm_certificate_url': '',
    'ssm_verified': false,
    'food_safety_doc_url': '',
    'food_safety_verified': false,
    'typhoid_vaccine_url': '',
    'typhoid_verified': false,
    'food_handling_cert_url': '',
    'food_handling_verified': false,
    'follows_moh_practices': false,
    'verified_status': false,
    'submitted_at': null,
  };

  Future<void> _pickAndUpload(String fieldUrl, String fieldVerified) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null && currentUser != null) {
      final file = File(picked.path);
      final ref = storage.ref('certifications/${currentUser!.uid}/$fieldUrl.jpg');

      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      setState(() {
        formState[fieldUrl] = downloadUrl;
        formState[fieldVerified] = true;
      });
    }
  }

  Future<void> _checkAndSubmitAll() async {
    bool allFieldsUploaded = 
        formState['ssm_certificate_url'] != '' &&
        formState['food_safety_doc_url'] != '' &&
        formState['typhoid_vaccine_url'] != '' &&
        formState['food_handling_cert_url'] != '' &&
        formState['follows_moh_practices'];

    if (!allFieldsUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload all required documents.")),
      );
      return;
    }

    formState['verified_status'] = true;
    formState['submitted_at'] = Timestamp.now();
    formState['vendor_id'] = currentUser!.uid;

    final snapshot = await firestore
        .collection('vendor_verify')
        .where('vendor_id', isEqualTo: currentUser!.uid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.update(formState);
    } else {
      await firestore.collection('vendor_verify').add(formState);
    }

    Navigator.pop(context, true);
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Food Safety Verification"),
        centerTitle: true,
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: currentStep,
        onStepContinue: () {
          if (currentStep < 4) {
            setState(() => currentStep++);
          }
        },
        onStepCancel: () {
          if (currentStep > 0) {
            setState(() => currentStep--);
          }
        },
        controlsBuilder: (context, details) {
          final isLastStep = currentStep == 4;
          return Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  if (isLastStep) {
                    await _checkAndSubmitAll(); 
                  } else {
                    details.onStepContinue!();
                  }
                },
                child: Text(isLastStep ? 'Submit' : 'Continue'),
              ),
              const SizedBox(width: 8),
              if (currentStep != 0)
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
          );
        },
        steps: [
          _buildUploadStep(
            "SSM Certificate",
            'ssm_certificate_url',
            'ssm_verified',
            0,
            "The SSM (Suruhanjaya Syarikat Malaysia) Certificate is a legal registration document proving that your business is registered with the Malaysian Companies Commission. This is essential for ensuring that all food vendors are operating as legitimate entities.\n\nYou can register your business online via the SSM Ezbiz Portal or visit an SSM office."
          ),
          _buildUploadStep(
            "Food Safety Document",
            'food_safety_doc_url',
            'food_safety_verified',
            1,
            "The Food Safety Document ensures that you comply with guidelines that reduce the risk of food contamination during preparation, handling, and storage. \n\nThis may include certification from courses or government inspections under the Food Hygiene Regulations 2009."
          ),
          _buildUploadStep(
            "Typhoid Vaccine",
            'typhoid_vaccine_url',
            'typhoid_verified',
            2,
            "A Typhoid Vaccine Record proves that food handlers have been vaccinated against typhoid fever, a disease that can be transmitted through food and water. \n\nYou can obtain the vaccine from clinics or government health centers and request an official vaccination certificate."
          ),
          _buildUploadStep(
            "Food Handling Cert",
            'food_handling_cert_url',
            'food_handling_verified',
            3,
            "This certificate shows that you have completed a certified food handling training course approved by the Ministry of Health. \n\nEnroll in an online or physical course by MOH-recognized training providers. You’ll receive a certificate after passing."
          ),
          Step(
            title: const Text("MOH Practices"),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "By enabling this, you confirm that you follow the Ministry of Health (MOH) recommended practices, including:",
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("• Wash hands before and after handling food"),
                      Text("• Use clean and sanitized equipment and surfaces"),
                      Text("• Store food at safe temperatures"),
                      Text("• Separate raw and cooked food to prevent cross-contamination"),
                      Text("• Wear proper attire (e.g. gloves, hairnet, apron) while preparing food"),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text("I follow MOH recommended practices"),
                  value: formState['follows_moh_practices'],
                  onChanged: (value) {
                    setState(() => formState['follows_moh_practices'] = value);
                  },
                ),
              ],
            ),
            isActive: currentStep == 4,
            state: currentStep > 4
                ? StepState.complete
                : currentStep == 4
                    ? StepState.editing
                    : StepState.indexed,
          ),
        ],
      ),
    );
  }

  Step _buildUploadStep(String label, String fieldUrl, String fieldVerified, int stepIndex, String description) {
    final verified = formState[fieldVerified];
    final url = formState[fieldUrl];

    return Step(
      title: Text(label),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: GestureDetector(
    onTap: url.isNotEmpty
        ? () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(
                  child: Image.network(url),
                ),
              ),
            );
          }
        : null, // Disable tap when URL is empty
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: verified ? Colors.green : Colors.red,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url.isNotEmpty
            ? Image.network(
                url,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            : Container(
                height: 160,
                width: double.infinity,
                color: Colors.grey[300],
                child: const Icon(Icons.image, size: 60, color: Colors.grey),
              ),
      ),
    ),
  ),
),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              description,
              textAlign: TextAlign.justify,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _pickAndUpload(fieldUrl, fieldVerified),
              icon: Icon(
                verified ? Icons.check_circle : Icons.upload_file,
                color: verified ? Colors.green : null,
              ),
              label: Text(
                verified ? "Uploaded" : "Upload File",
                style: TextStyle(color: verified ? Colors.green : null),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: verified ? Colors.green.shade50 : null,
                side: verified
                    ? const BorderSide(color: Colors.green)
                    : BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),

      isActive: currentStep == stepIndex,
      state: currentStep > stepIndex ? StepState.complete : StepState.indexed,
    );
  }

}
