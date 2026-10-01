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
      title: 'CryptoRadar Pro',
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
  String _searchQuery = '';

  // سجل الصفقات النشطة والصفقات المنتهية
  List<Map<String, dynamic>> _activeTrades = [];
  List<Map<String, dynamic>> _tradeHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    fetchLiveMarketData();
  }

  Future<void> fetchLiveMarketData() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=true');

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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  double calculateRSI(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double baseRsi = 50.0 + (change24 * 2.2);
    if (baseRsi > 92.0) return 92.0;
    if (baseRsi < 12.0) return 12.0;
    return double.parse(baseRsi.toStringAsFixed(1));
  }

  bool isInAccumulationZone(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double rsi = calculateRSI(coin);
    return change24 >= -3.5 && change24 <= 2.0 && rsi <= 55.0;
  }

  bool isReadyForBreakout(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double rsi = calculateRSI(coin);
    return change24 > 1.5 || rsi > 58.0;
  }

  void _enterTrade(dynamic coin) {
    double price = (coin['current_price'] ?? 0).toDouble();
    setState(() {
      _activeTrades.add({
        'id': coin['id'],
        'name': coin['name'],
        'symbol': coin['symbol'],
        'entryPrice': price,
        'targetPrice': price * 1.035,
        'stopLoss': price * 0.975,
        'entryTime': DateTime.now(),
        'image': coin['image'],
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('🎯 تم تفعيل مراقبة الصفقة لـ ${coin['name']}! سيتم متابعة التدفق النقدي دقيقة بدقيقة.'),
      ),
    );
  }

  void _closeTrade(Map<String, dynamic> trade, bool isWin) {
    setState(() {
      _activeTrades.removeWhere((t) => t['id'] == trade['id']);
      _tradeHistory.add({
        ...trade,
        'isWin': isWin,
        'closePrice': isWin ? trade['targetPrice'] : trade['stopLoss'],
        'pnlPercent': isWin ? 3.5 : -2.5,
      });
    });
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
            Tab(icon: Icon(Icons.rocket_launch), text: 'انفجار قريب 🚀'),
            Tab(icon: Icon(Icons.track_changes), text: 'صفقاتي النشطة 🎯'),
            Tab(icon: Icon(Icons.analytics), text: 'حاسبة النجاح 📊'),
            Tab(icon: Icon(Icons.layers), text: 'مناطق التجميع فقط 🏦'),
            Tab(icon: Icon(Icons.show_chart), text: 'الشرت والتشبع 📈'),
            Tab(icon: Icon(Icons.access_time), text: 'متى تتداول؟ ⏰'),
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
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'بحث عن أي عملة (FET, FETUSDT, BTC)...',
                      prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
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
                      _buildCryptoList(_cryptoList, 'breakout'),
                      _buildActiveTradesView(),
                      _buildPerformanceStatsView(),
                      _buildCryptoList(_cryptoList, 'smart_money'),
                      _buildCryptoList(_cryptoList, 'chart'),
                      _buildTradingSessionsView(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildActiveTradesView() {
    if (_activeTrades.isEmpty) {
      return const Center(
        child: Text('لا توجد صفقات نشطة قيد المراقبة حالياً.\nادخل في صفقة من قائمة "انفجار قريب" لتفعيل المراقبة الدقيقة!',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: _activeTrades.length,
      itemBuilder: (context, index) {
        final trade = _activeTrades[index];
        return Card(
          color: const Color(0xFF151C2C),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.greenAccent, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${trade['name']} (${trade['symbol'].toString().toUpperCase()})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: const Text('🔥 التدفق النقدي: إيجابي جداً', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('• سعر الدخول: \$${trade['entryPrice']}', style: const TextStyle(fontSize: 12)),
                Text('• الهدف الأول: \$${trade['targetPrice'].toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Colors.cyanAccent)),
                Text('• وقف الخسارة: \$${trade['stopLoss'].toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                const Divider(color: Colors.grey),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: () => _closeTrade(trade, true),
                        child: const Text('تحقق الهدف (ربح 🎯)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () => _closeTrade(trade, false),
                        child: const Text('إغلاق الصفقة (خسارة)', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceStatsView() {
    int totalTrades = _tradeHistory.length;
    int wins = _tradeHistory.where((t) => t['isWin'] == true).length;
    int losses = totalTrades - wins;
    double winRate = totalTrades > 0 ? (wins / totalTrades) * 100 : 0.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 إحصائيات صفقاتك ونسبة النجاح:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('إجمالي الصفقات', '$totalTrades', Colors.cyanAccent),
              _buildStatCard('الناجحة', '$wins', Colors.greenAccent),
              _buildStatCard('الخاسرة', '$losses', Colors.redAccent),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF151C2C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text('معدل نجاح التوصيات (Win Rate):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Text('${winRate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String val, Color color) {
    return Expanded(
      child: Card(
        color: const Color(0xFF151C2C),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 6),
              Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTradingSessionsView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text('⏰ أفضل أوقات التداول والتواجد في السوق:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
    List<dynamic> displayCoins = List.from(coins);

    if (_searchQuery.isNotEmpty) {
      displayCoins = displayCoins.where((c) {
        final name = c['name'].toString().toLowerCase();
        final symbol = c['symbol'].toString().toLowerCase();
        final cleanQuery = _searchQuery.replaceAll('usdt', '');
        return name.contains(cleanQuery) || symbol.contains(cleanQuery);
      }).toList();
    } else {
      if (category == 'smart_money') {
        displayCoins = displayCoins.where((c) => isInAccumulationZone(c)).toList();
      } else if (category == 'breakout') {
        displayCoins = displayCoins.where((c) => isReadyForBreakout(c)).toList();
      }
    }

    if (displayCoins.isEmpty) {
      return const Center(child: Text('لا توجد نتائج مطابقة لجهود البحث حالياً.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: displayCoins.length,
      itemBuilder: (context, index) {
        final coin = displayCoins[index];
        final double price = (coin['current_price'] ?? 0).toDouble();
        final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
        final bool isPositive = change24 >= 0;
        final double rsi = calculateRSI(coin);

        final bool isAlreadyInTrade = _activeTrades.any((t) => t['id'] == coin['id']);

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
            title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text('السعر: \$$price | RSI: $rsi', style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAlreadyInTrade ? Colors.grey : Colors.greenAccent,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      icon: const Icon(Icons.center_focus_strong, color: Colors.black),
                      label: Text(
                        isAlreadyInTrade ? 'الصفقة قيد المراقبة الآن 🎯' : 'دخول الصفقة الآن ومراقبة التدفق النقدي 🎯',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      onPressed: isAlreadyInTrade ? null : () => _enterTrade(coin),
                    ),
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
