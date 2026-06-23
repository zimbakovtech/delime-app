import 'package:delime/data/app_repository.dart';
import 'package:delime/data/database.dart';
import 'package:delime/data/file_receipt_store.dart';
import 'package:delime/screens/trips_screen.dart';
import 'package:delime/state/app_state.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final repository = AppRepository(AppDatabase.instance);
  final receipts = FileReceiptStore();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(repository, receipts: receipts)..load(),
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
      home: const TripsScreen(),
    );
  }
}
