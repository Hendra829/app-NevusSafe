import 'package:flutter/material.dart';

void main() => runApp(const NevusSafeApp());

class NevusSafeApp extends StatelessWidget {
  const NevusSafeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'NevusSafe',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(title: const Text('NevusSafe')),
          body: const Center(
            child: Text('Your encrypted vault is ready. Sign in to sync.'),
          ),
        ),
      );
}
