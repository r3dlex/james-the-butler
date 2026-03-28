import 'package:flutter/material.dart';

void main() {
  runApp(const JamesTheButlerApp());
}

class JamesTheButlerApp extends StatelessWidget {
  const JamesTheButlerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'James the Butler',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('James the Butler'),
        ),
      ),
    );
  }
}
