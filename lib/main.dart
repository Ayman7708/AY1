import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
      // دعم اللغة العربية وتوجيه الواجهة من اليمين لليسار
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          elevation: 0,
        ),
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _cryptoList = [];
  List<dynamic> _filteredList = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchLiveCryptoData();
  }

  // جلب الأسعار والبيانات المباشرة من إنترنت حقيقي عبر API
  Future<void> fetchLiveCryptoData() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=50&page=1&sparkline=false');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _cryptoList = data;
          _filteredList = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredList = _cryptoList.where((coin) {
        final name = coin['name'].toString().toLowerCase();
        final symbol = coin['symbol'].toString().toLowerCase();
        return name.contains(query.toLowerCase()) || symbol.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radar, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('CryptoRadar Pro', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: fetchLiveCryptoData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.show_chart), text: 'الأسواق الحية'),
            Tab(icon: Icon(Icons.waves), text: 'تجميع الحيتان'),
            Tab(icon: Icon(Icons.bolt), text: 'جاهزة للانفجار'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Column(
              children: [
                // شريط البحث
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    onChanged: _filterSearch,
                    decoration: InputDecoration(
                      hintText: 'بحث عن عملة (مثال: BTC, SOL)...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCryptoList(_filteredList, 'all'),
                      _buildCryptoList(_filteredList, 'whales'),
                      _buildCryptoList(_filteredList, 'breakout'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCryptoList(List<dynamic> coins, String type) {
    List<dynamic> displayCoins = List.from(coins);

    // تصفية الذكاء الاصطناعي/المؤشرات:
    if (type == 'whales') {
      // رادار الحيتان: اختيار العملات التي تشهد نسبة حجم تداول ضخمة مقارنة برأس المال
      displayCoins = displayCoins.where((c) {
        double vol = (c['total_volume'] ?? 0).toDouble();
        double cap = (c['market_cap'] ?? 1).toDouble();
        return (vol / cap) > 0.15; // حجم التداول أكثر من 15% من رأس المال
      }).toList();
    } else if (type == 'breakout') {
      // عملات تستعد للانفجار: ارتفاع إيجابي مع زخم صعودي قوي
      displayCoins = displayCoins.where((c) {
        double change = (c['price_change_percentage_24h'] ?? 0).toDouble();
        return change > 3.0; 
      }).toList();
    }

    if (displayCoins.isEmpty) {
      return const Center(child: Text('لا توجد عملات تطابق هذا التصفية حالياً'));
    }

    return ListView.builder(
      itemCount: displayCoins.length,
      itemBuilder: (context, index) {
        final coin = displayCoins[index];
        final price = coin['current_price'] ?? 0;
        final change24 = coin['price_change_percentage_24h'] ?? 0;
        final bool isPositive = change24 >= 0;

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Image.network(
                coin['image'] ?? '',
                errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin),
              ),
            ),
            title: Text(
              '${coin['name']} (${coin['symbol'].toString().toUpperCase()})',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            subtitle: Text(
              '\$$price',
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${change24.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            children: [
              // تفاصيل المؤشرات وصنع الصفقات (قصيرة/طويلة الأجل)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.grey),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('القيمة السوقية: \$${(coin['market_cap'] / 1000000).toStringAsFixed(1)}M'),
                        Text('حجم 24س: \$${(coin['total_volume'] / 1000000).toStringAsFixed(1)}M'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            isPositive ? 'صفقة قصيرة (Scalp): دخول شراء' : 'صفقة قصيرة (Scalp): انتظار/بيع',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: isPositive ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            type == 'whales' ? 'استثمار طويل: تجميع حيتان ممتاز' : 'استثمار طويل: تعزيز تدريجي',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.blueGrey.shade800,
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
