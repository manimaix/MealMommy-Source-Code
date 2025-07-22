import 'package:mealmommy_application/services/database_service.dart';

class LoginService {
  /// Fetches all users from the 'users' collection and prints them to the console.
  Future<void> printAllUsers() async {
    final users = await FirebaseService.instance.fetchAllDocuments('users');
    for (final user in users) {
      print(user);
    }
  }
}
