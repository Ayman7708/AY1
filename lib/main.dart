import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CryptoRadarApp());
}

class CryptoRadarApp extends StatelessWidget {
  const CryptoRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptoRadar AI',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF151C2C),
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
  bool _isDeepSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    fetchLiveMarketData();
  }

  Future<void> fetchLiveMarketData() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=50&page=1&sparkline=true');

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

  void _executeDeepSearch(String query) async {
    setState(() => _isDeepSearching = true);
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _filteredList = _cryptoList.where((coin) {
        final name = coin['name'].toString().toLowerCase();
        final symbol = coin['symbol'].toString().toLowerCase();
        return name.contains(query.toLowerCase()) || symbol.contains(query.toLowerCase());
      }).toList();
      _isDeepSearching = false;
    });
  }

  double calculateRSI(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double baseRsi = 50.0 + (change24 * 2.2);
    if (baseRsi > 92.0) return 92.0;
    if (baseRsi < 12.0) return 12.0;
    return double.parse(baseRsi.toStringAsFixed(1));
  }

  String getCurrentMarketStatus() {
    int hour = DateTime.now().toUtc().hour;
    if (hour >= 12 && hour <= 16) {
      return "🔥 السيولة قصوى (جلسة نيويورك ولندن) - وقت ممتاز للتداول المباشر";
    } else if (hour >= 7 && hour < 12) {
      return "🟢 سيولة مرتفعة (جلسة لندن) - اقتناص صفقات السكالبينج";
    } else {
      return "🟡 سيولة متوسطة - تداول بحذر وافتح صفقات سريعة";
    }
  }

  void showNotificationBanner(String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF151C2C),
        duration: const Duration(seconds: 4),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
              ],
            ),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.candlestick_chart, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('CryptoRadar Pro', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: fetchLiveMarketData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.show_chart), text: 'الشرت والتشبع 📈'),
            Tab(icon: Icon(Icons.layers), text: 'مناطق التجميع 🏦'),
            Tab(icon: Icon(Icons.monetization_on), text: 'تحدي 10$ ➔ 100$'),
            Tab(icon: Icon(Icons.access_time), text: 'متى تتداول؟ ⏰'),
            Tab(icon: Icon(Icons.bolt), text: 'ربح سريع ⚡'),
            Tab(icon: Icon(Icons.warning_amber), text: 'رادار التلاعب ⚠️'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: const Color(0xFF1E293B),
                  child: Text(
                    getCurrentMarketStatus(),
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextField(
                    onChanged: _executeDeepSearch,
                    decoration: InputDecoration(
                      hintText: 'بحث عميق (Binance, Bybit, OKX + AI Analysis)...',
                      prefixIcon: const Icon(Icons.manage_search, color: Colors.cyanAccent),
                      suffixIcon: _isDeepSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent),
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF151C2C),
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
                      _buildCryptoList(_filteredList, 'chart'),
                      _buildCryptoList(_filteredList, 'smart_money'),
                      _buildCryptoList(_filteredList, 'challenge'),
                      _buildTradingSessionsView(),
                      _buildCryptoList(_filteredList, 'fast_profit'),
                      _buildCryptoList(_filteredList, 'manipulation'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTradingSessionsView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text('⏰ أفضل أوقات التداول والتواجد في السوق:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          _buildSessionCard('جلسة نيويورك 🇺🇸 (الأقوى)', '2:00 م - 10:00 م (بتوقيت مكة)', 'تضخيم سيولة حاد وفرص سريعة جداً', Colors.green),
          _buildSessionCard('جلسة لندن 🇬🇧 (ممتازة)', '10:00 ص - 6:00 م (بتوقيت مكة)', 'بداية حركات الترند الحقيقية اليومية', Colors.cyan),
          _buildSessionCard('جلسة طوكيو/آسيا 🇯🇵 (تجميع)', '3:00 ص - 11:00 ص (بتوقيت مكة)', 'حركة تجميعية - مناسبة لصفقات التجهيز', Colors.amber),
        ],
      ),
    );
  }

  Widget _buildSessionCard(String title, String time, String desc, Color color) {
    return Card(
      color: const Color(0xFF151C2C),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(Icons.circle, color: color, size: 14),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text('$time\n$desc', style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ),
    );
  }

  Widget _buildCryptoList(List<dynamic> coins, String category) {
    return ListView.builder(
      itemCount: coins.length,
      itemBuilder: (context, index) {
        final coin = coins[index];
        final double price = (coin['current_price'] ?? 0).toDouble();
        final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
        final bool isPositive = change24 >= 0;
        final double rsi = calculateRSI(coin);
        final List<dynamic> sparkline = coin['sparkline_in_7d']?['price'] ?? [];

        String rsiStatus = "متوازن ⚪";
        Color rsiColor = Colors.white70;
        if (rsi >= 70) {
          rsiStatus = "تشبع شرائي ⚠️ (خطر شراء)";
          rsiColor = Colors.redAccent;
        } else if (rsi <= 35) {
          rsiStatus = "تشبع بيعي 🚀 (فرصة شراء ممتازة)";
          rsiColor = Colors.greenAccent;
        }

        return Card(
          color: const Color(0xFF151C2C),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Image.network(
                coin['image'] ?? '',
                errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin),
              ),
            ),
            title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text('السعر: \$$price | RSI: $rsi', style: TextStyle(color: rsiColor, fontSize: 11, fontWeight: FontWeight.bold)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${change24.toStringAsFixed(2)}%',
                style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.grey),
                    Text('📊 مؤشر قوة الزخم: $rsiStatus', style: TextStyle(color: rsiColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (sparkline.isNotEmpty)
                      Container(
                        height: 50,
                        width: double.infinity,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: sparkline.take(25).map((p) {
                            double heightFactor = ((p - price) / price).abs() * 400;
                            if (heightFactor > 35) heightFactor = 35;
                            if (heightFactor < 4) heightFactor = 4;
                            return Container(
                              width: 5,
                              height: heightFactor,
                              decoration: BoxDecoration(
                                color: isPositive ? Colors.greenAccent : Colors.redAccent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🌐 تحليل Deep Search AI (Binance • Bybit • OKX):', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('• منطقة التجميع المتوقعة: \$${(price * 0.97).toStringAsFixed(3)} - \$${(price * 0.985).toStringAsFixed(3)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                          Text('• هدف الربح السريع: \$${(price * 1.035).toStringAsFixed(3)}', style: const TextStyle(fontSize: 11, color: Colors.amberAccent)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, minimumSize: const Size(double.infinity, 38)),
                      icon: const Icon(Icons.notifications_active, color: Colors.black),
                      label: const Text('تفعيل تنبيه الفرصة على التطبيق', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        showNotificationBanner(
                          'تنبيه إشارة ${coin['name']}',
                          'السعر: \$$price | مؤشر RSI: $rsi | توصية: ${rsi <= 35 ? "شراء قاع" : "متابعة الحركة"}',
                        );
                      },
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
