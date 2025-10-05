import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// screens
import 'screens/home_screen.dart';
import 'firebase_enabled.dart';
import 'screens/parking_detail_A.dart';
import 'screens/parking_detail_B.dart';
import 'screens/parking_detail_C.dart';
import 'screens/parking_map_screen.dart';
import 'screens/parking_selection_screen.dart';
import 'services/services_seed_fake.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // If you generated `lib/firebase_options.dart` (flutterfire configure)
    // prefer using the generated options. If the values are still the
    // placeholder values below the call will likely fail to connect and
    // be caught below.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Fallback to using platform defaults if for some reason the generated
      // options can't be used at runtime (for example when running on a
      // platform where the options aren't required/available).
      await Firebase.initializeApp(); // initialize Firebase (uses platform defaults)
    }
    // Print platform and RTDB URL to help diagnosing web vs mobile initialization
    print(
      '[Firebase] initializeApp(): OK (platform=web? $kIsWeb) dbURL=${Firebase.app().options.databaseURL}',
    );

    // Anonymous sign-in (optional): enable by adding the
    // `firebase_auth` dependency and running `flutter pub get`, then
    // uncommenting the sign-in call below.
    // Example:
    //   final cred = await FirebaseAuth.instance.signInAnonymously();
    //   print('[Auth] Anonymous UID = ${cred.user?.uid}');
    // For now we skip sign-in so the app compiles when the package
    // hasn't been fetched yet.
    print(
      '[Auth] anonymous sign-in skipped (enable by adding firebase_auth + pub get)',
    );

    runApp(ParkingApp());
  } catch (e, st) {
    // mark flag so UI can avoid calling Firebase APIs and continue running the app
    firebaseEnabled = false;
    print('[Firebase] initializeApp() failed: $e');
    print(st);
    // Seed the fake DB so UI can show data when Firebase isn't available.
    try {
      await FakeSeeder.seedFromAsset('assets/parking_schema_minimal.json');
      print('[FakeSeeder] seeded from assets/parking_schema_minimal.json');
    } catch (se) {
      print('[FakeSeeder] seed failed: $se');
    }
    // Continue running the app so you can test UI even without Firebase configured.
    runApp(ParkingApp());
  }
}

class ParkingApp extends StatelessWidget {
  const ParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parking Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFE8F0FE),
      ),
      home: HomeScreen(),
      routes: {
        '/home': (context) => HomeScreen(),
        // '/login': (context) => LoginScreen(),
        '/parkingA': (context) => ParkingDetailAScreen(),
        '/parkingB': (context) => ParkingDetailBScreen(),
        '/parkingC': (context) => ParkingDetailCScreen(),
        '/parking-selection': (context) => ParkingSelectionScreen(),
        '/parking-map': (context) => ParkingMapScreen(),
        '/map': (context) => ParkingMapScreen(),
        '/parking-detail': (context) => ParkingSelectionScreen(),
        // '/settings': (context) => SettingsScreen(),
      },
    );
  }
}
