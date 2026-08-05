import 'package:flutter/material.dart';
import 'core/theme/theme.dart';
import 'presentation/navigation/main_shell.dart';

class UbuntuElimuApp extends StatelessWidget {
  const UbuntuElimuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ubuntu Elimu',
      debugShowCheckedModeBanner: false,
      theme: UETheme.darkTheme,
      home: const MainShell(),
    );
  }
}
