import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../global_app_bar.dart';
import 'package:intl/intl.dart';


class CertificatePage extends StatefulWidget {
  const CertificatePage({super.key});

  @override
  State<CertificatePage> createState() => _CertificatePageState();
}

class _CertificatePageState extends State<CertificatePage> {
  int _selectedIndex = 2;
  Map<String, dynamic>? certData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchVendorCertData();
  }
  
  Future<void> _deleteIfExists(String fieldName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final ref = FirebaseStorage.instance
          .ref('certifications/${currentUser.uid}/$fieldName.jpg');
      await ref.delete();
      debugPrint("Deleted $fieldName.jpg from storage");
    } catch (e) {
      debugPrint("Error deleting $fieldName.jpg: $e");
    }
  }


  Future<void> fetchVendorCertData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('vendor_verify')
        .where('vendor_id', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final docRef = snapshot.docs.first.reference;
      certData = snapshot.docs.first.data();

      final submittedAt = certData!["submitted_at"];
      bool isExpired = false;

      // Check expiry
      if (submittedAt is Timestamp) {
        isExpired = _isExpired(submittedAt);
      }

      if (isExpired) {
        await _deleteIfExists("ssm_certificate_url");
        await _deleteIfExists("food_safety_doc_url");
        await _deleteIfExists("typhoid_vaccine_url");
        await _deleteIfExists("food_handling_cert_url");

        await docRef.update({
          "ssm_verified": false,
          "food_safety_verified": false,
          "typhoid_verified": false,
          "food_handling_verified": false,
          "follows_moh_practices": false,
          "verified_status": false,
          "ssm_certificate_url": "",
          "food_safety_doc_url": "",
          "typhoid_vaccine_url": "",
          "food_handling_cert_url": "",
          "submitted_at": null,
        });

        certData = {
          "ssm_verified": false,
          "food_safety_verified": false,
          "typhoid_verified": false,
          "food_handling_verified": false,
          "follows_moh_practices": false,
          "verified_status": false,
          "submitted_at": null,
        };

        setState(() {
          loading = false;
        });

        return;
      } else {
        bool allVerified = certData!["ssm_verified"] == true &&
                          certData!["food_safety_verified"] == true &&
                          certData!["typhoid_verified"] == true &&
                          certData!["food_handling_verified"] == true &&
                          certData!["follows_moh_practices"] == true;

        await docRef.update({
          "verified_status": allVerified,
        });

        certData!["verified_status"] = allVerified;
      }

      setState(() {
        loading = false;
      });
    } else {

      // No certification data found, initialize with default values
      setState(() {
        certData = {
          "ssm_verified": false,
          "food_safety_verified": false,
          "typhoid_verified": false,
          "food_handling_verified": false,
          "follows_moh_practices": false,
          "verified_status": false,
          "submitted_at": null,
        };
        loading = false;
      });
    }
  }


  bool _isExpired(dynamic submittedAtRaw) {
    if (submittedAtRaw == null || submittedAtRaw is! Timestamp) return false;

    final date = submittedAtRaw.toDate();
    final oneYearLater = DateTime(date.year + 1, date.month, date.day);
    return DateTime.now().isAfter(oneYearLater);
  }


  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (certData == null) {
      return const Scaffold(
        body: Center(child: Text("No certification data found.")),
      );
    }

    return Scaffold(
      appBar: const GlobalAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Certifications",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  buildRow(
                    title: "SSM Registration",
                    subtitle: certData!["ssm_certificate_url"] != null
                        ? "Certificate uploaded"
                        : "Not uploaded",
                    verified: certData!["ssm_verified"] ?? false,
                  ),
                  buildRow(
                    title: "Food Safety Info",
                    subtitle: certData!["food_safety_doc_url"] != null
                        ? "MOH-issued certificate uploaded"
                        : "Not uploaded",
                    verified: certData!["food_safety_verified"] ?? false,
                  ),
                  buildRow(
                    title: "Anti-typhoid Vaccine",
                    subtitle: certData!["typhoid_vaccine_url"] != null
                        ? "Vaccination proof uploaded"
                        : "Not uploaded",
                    verified: certData!["typhoid_verified"] ?? false,
                  ),
                  buildRow(
                    title: "Food Handling Course",
                    subtitle: certData!["food_handling_cert_url"] != null
                        ? "Course certificate uploaded"
                        : "Not uploaded",
                    verified: certData!["food_handling_verified"] ?? false,
                  ),
                  buildRow(
                    title: "Follow MOH Practices",
                    subtitle: certData!["follows_moh_practices"] == true
                        ? "Self-declared"
                        : "Not declared",
                    verified: certData!["follows_moh_practices"] ?? false,
                  ),
                  const SizedBox(height: 12),
                  if (certData!["submitted_at"] != null)
                  Center(
                    child: Column(
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd').format(
                            (certData!["submitted_at"] as Timestamp).toDate(),
                          ),
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        if (_isExpired(certData!["submitted_at"]))
                          const Text(
                            "❗ Certification expired. Please re-upload your documents.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async{
                  if (certData!["verified_status"] == false) {
                    final result = await Navigator.of(context).pushNamed('/foodsafety');
                    if (result == true) {
                      await fetchVendorCertData();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("All certifications are verified.")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Upload",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
              bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: "Orders"),
            BottomNavigationBarItem(icon: Icon(Icons.fastfood), label: "Food List"),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: "Menu"),
            BottomNavigationBarItem(icon: Icon(Icons.money), label: "Revenue"),
          ],
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            switch (index) {
              case 0:
                Navigator.of(context).pushReplacementNamed('/order');
                break;
              case 1:
                Navigator.of(context).pushReplacementNamed('/foodList');
                break;
              case 2:
                Navigator.of(context).pushReplacementNamed('/vendor');
                break;
              case 3:
                Navigator.of(context).pushReplacementNamed('/menu');
                break;
              case 4:
                Navigator.of(context).pushReplacementNamed('/revenue');
                break;
            }
          },
        ),

    );
  }

  Widget buildRow({
    required String title,
    required String subtitle,
    required bool verified,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: verified ? Colors.green[100] : Colors.red[100],
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(
              verified ? Icons.check : Icons.close,
              color: verified ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
