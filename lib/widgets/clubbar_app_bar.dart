import 'package:flutter/material.dart';

class ClubbarAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ClubbarAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: true, // 🔥 CENTRALIZA

      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/logo.png', height: 28),
          const SizedBox(width: 10),
          const Text(
            'Clubbar',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),

      // ❌ REMOVE logout
      actions: const [],
    );
  }
}
