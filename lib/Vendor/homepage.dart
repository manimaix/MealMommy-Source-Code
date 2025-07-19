import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatelessWidget {
  final CollectionReference foodItems =
      FirebaseFirestore.instance.collection('foods');

  final TextEditingController _nameController = TextEditingController();

  HomePage({super.key});

  void _addFood() {
    if (_nameController.text.isNotEmpty) {
      foodItems.add({'name': _nameController.text});
      _nameController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Food List')),
      body: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'Enter food name'),
          ),
          ElevatedButton(
            onPressed: _addFood,
            child: Text('Add Food'),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: foodItems.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Text('Error');
                if (!snapshot.hasData) return CircularProgressIndicator();

                final docs = snapshot.data!.docs;

                return ListView(
                  children: docs.map((doc) {
                    return ListTile(
                      title: Text(doc['name']),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
