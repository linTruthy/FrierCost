import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'navigation_shell.dart';

import 'utils.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: ShimmerWidget(
                child: Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[300],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return LoginPage();
        }

        return const NavigationShell();
      },
    );
  }
}
