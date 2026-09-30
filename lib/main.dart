import 'package:flutter/material.dart';

void main() {
  runApp(const CryptoRadarApp());
}

class CryptoRadarApp extends StatelessWidget {
  const CryptoRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptoRadar',
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('CryptoRadar'),
          centerTitle: true,
        ),
        body: const Center(
          child: Text('مرحباً بك في تطبيق CryptoRadar'),
        ),
      ),
    );
  }
}
