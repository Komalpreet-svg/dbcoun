import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dba_dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ServerApp());
}

class ServerApp extends StatelessWidget {
  const ServerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DBA Control Center',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DbaDashboardScreen(),
    );
  }
}
