import 'package:flutter/material.dart';
import '../models/user_model.dart';

class GlobalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser? currentUser;
  final VoidCallback? onSignOut;
  final VoidCallback? onProfile;
  final List<Widget>? actions;

  const GlobalAppBar({
    Key? key,
    this.currentUser,
    this.onSignOut,
    this.onProfile,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Image.asset('assets/icons/Logo.png', width: 40),
          SizedBox(width: 10),
          Text(
            'Meal Mommy',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      elevation: 0.0,
      backgroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.black),
      actions: actions ?? [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: InkWell(
            child: Icon(
              Icons.notifications,
              size: 24,
              color: Colors.black, // Customize color if needed
            ),
          ),
        ),
        IconButton(
          icon: CircleAvatar(
            backgroundImage: currentUser?.profileImage != null
                ? NetworkImage(currentUser!.profileImage!)
                : AssetImage('assets/icons/default_avatar.png') as ImageProvider,
          ),
          onPressed: onProfile,
          tooltip: 'Profile',
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: onSignOut,
          tooltip: 'Sign Out',
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
