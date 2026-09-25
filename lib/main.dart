import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const CryptoAiApp());
}

class CryptoAiApp extends StatelessWidget {
  const CryptoAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crypto AI Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _coinController = TextEditingController(text: 'bitcoin');
  final TextEditingController _apiKeyController = TextEditingController();
  
  bool _isLoading = false;
  String _resultText = '';
  String _priceText = '';

  // رابط الخادم المحلي (عند تشغيل التطبيق في نفس الهاتف نستخدم localhost)
  final String _serverUrl = 'http://127.0.0.1:8000/analyze';

  Future<void> _analyzeCrypto() async {
    setState(() {
      _isLoading = true;
      _resultText = '';
      _priceText = '';
    });

    try {
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'coin_id': _coinController.text.trim().toLowerCase(),
          'vs_currency': 'usd',
          'api_key': _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _priceText = 'السعر الحالي: \$${data['price']} (التغير 24h: ${data['change_24h'].toStringAsFixed(2)}%)';
          _resultText = data['ai_analysis'];
        });
      } else {
        setState(() {
          _resultText = 'خطأ في الاستجابة: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _resultText = 'فشل الاتصال بالخادم: $e\nتأكد من تشغيل الخادم في Termux أولاً.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('محلل العملات الذكي'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _coinController,
                decoration: const InputDecoration(
                  labelText: 'اسم العملة (مثال: bitcoin, ethereum, solana)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_bitcoin),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'مفتاح OpenAI / DeepSeek API (اختياري)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyzeCrypto,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics),
                label: Text(_isLoading ? 'جاري التحليل...' : 'تحليل العملة الآن'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 24),
              if (_priceText.isNotEmpty)
                Card(
                  color: Colors.deepPurple.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      _priceText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (_resultText.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple.shade400),
                  ),
                  child: Text(
                    _resultText,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                    textDirection: TextDirection.rtl,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
