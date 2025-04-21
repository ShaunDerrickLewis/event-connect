import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  String? _email;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _email = user.email;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      _ageController.text = data['age'] ?? '';
      _genderController.text = data['gender'] ?? '';
      _phoneController.text = data['phone'] ?? '';
      _aboutController.text = data['about'] ?? '';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveField(String key, String value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {key: value},
      SetOptions(merge: true),
    );
  }

  Widget _editableField(String label, TextEditingController controller, String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              onFieldSubmitted: (val) => _saveField(key, val),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _saveField(key, controller.text.trim()),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    _genderController.dispose();
    _phoneController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Profile"),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
        ),
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 50,
                          backgroundImage: AssetImage('assets/profile_placeholder.png'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.email),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_email ?? '', style: const TextStyle(fontSize: 16))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _editableField("Age", _ageController, 'age'),
                        _editableField("Gender", _genderController, 'gender'),
                        _editableField("Phone", _phoneController, 'phone'),
                        _editableField("About", _aboutController, 'about'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text("Interested Events", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildInterestedEvents(),
                const SizedBox(height: 24),
ElevatedButton.icon(
  icon: const Icon(Icons.logout, color: Colors.white),
  label: const Text("Logout", style: TextStyle(color: Colors.white)),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  onPressed: () async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  },
),
              ],
            ),
          ),
  );
}


Widget _buildInterestedEvents() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return const Text("Not logged in");
  

  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('events')
        .where('interestedUserIds', arrayContains: uid)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const CircularProgressIndicator();

      final docs = snapshot.data!.docs;
      if (docs.isEmpty) {
        return const Text("You haven't marked interest in any event yet.");
      }

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final data = docs[index].data() as Map<String, dynamic>;
          final docId = docs[index].id;
          final images = (data['imageUrls'] as List?)?.cast<String>() ?? [];

          return Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              title: Text(data['title'] ?? 'Untitled'),
              subtitle: Text(data['location'] ?? 'No location'),
              leading: images.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(images[0], width: 50, height: 50, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.image, size: 40),
              children: [
                ListTile(title: Text("Date: ${data['date'] ?? 'N/A'}")),
                ListTile(title: Text("Category: ${data['category'] ?? 'N/A'}")),
                ListTile(title: Text("Description: ${data['description'] ?? 'N/A'}")),
                TextButton.icon(
                  icon: const Icon(Icons.cancel),
                  label: const Text("Not Interested"),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('events').doc(docId).update({
                      'interestedUserIds': FieldValue.arrayRemove([uid]),
                      'interestedUserEmails': FieldValue.arrayRemove([FirebaseAuth.instance.currentUser?.email]),
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Removed from interested')),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}


}