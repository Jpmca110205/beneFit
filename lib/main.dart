import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game/app.dart';
import 'package:game/simple_bloc_observer.dart';
import 'package:user_repository/user_repository.dart';
import 'dart:io';

import 'package:provider/provider.dart';
import 'screens/auth/widgets/workoutProvider.dart'; 
import 'screens/auth/widgets/search_manager.dart';  // <-- import SearchManager

void testLocalNetwork() async {
  try {
    final socket = await Socket.connect('192.168.1.1', 80).timeout(const Duration(seconds: 2));
    socket.destroy();
  } catch (e) {
    print('Local network test failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  Bloc.observer = SimpleBlocObserver();
  testLocalNetwork();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => SearchManager()),  // <-- Add this provider here
      ],
      child: MyApp(FirebaseUserRepo()),
    ),
  );
}
