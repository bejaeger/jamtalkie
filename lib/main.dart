import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jamtalkie/app/app.bottomsheets.dart';
import 'package:jamtalkie/app/app.dialogs.dart';
import 'package:jamtalkie/app/app.locator.dart';
import 'package:jamtalkie/app/app.router.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.blue.withOpacity(0.5),
      systemNavigationBarColor: Colors.blue.withOpacity(0.5),
    ),
  );

  await setupLocator();
  setupDialogUi();
  setupBottomSheetUi();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JamTalkie',
      debugShowCheckedModeBanner: false,
      initialRoute: Routes.startupView,
      onGenerateRoute: StackedRouter().onGenerateRoute,
      navigatorKey: StackedService.navigatorKey,
      navigatorObservers: [
        StackedService.routeObserver,
      ],
      theme: ThemeData(
        primaryColor: Colors.blue,
      ),
    );
  }
}
