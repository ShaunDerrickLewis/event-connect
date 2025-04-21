import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login.dart';
import 'screens/main_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDDQ1OJlJpBAG-8btS7V0HAqQvBM2IPw6k",
      authDomain: "eventconnect-5c542.firebaseapp.com",
      projectId: "eventconnect-5c542",
      storageBucket: "eventconnect-5c542.firebasestorage.app",
      messagingSenderId: "1022770835137",
      appId: "1:1022770835137:web:7256af16a1cdf414d6ee40",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EventConnect',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/main': (context) => const MainNav(),
      },
    );
  }
}
