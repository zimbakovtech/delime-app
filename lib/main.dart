import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/app_repository.dart';
import 'data/database.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final repository = AppRepository(AppDatabase.instance);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(repository)..load(),
      child: const DelimeApp(),
    ),
  );
}

class DelimeApp extends StatelessWidget {
  const DelimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delime',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
