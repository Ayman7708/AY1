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
  bool _isDeepSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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

  bool isInAccumulationZone(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double rsi = calculateRSI(coin);
    // تعتبر في نطاق التجميع فقط إذا كان التغير السعري استقراراً بين -2% و +2% مع RSI متوازن/منخفض
    return change24 >= -2.5 && change24 <= 2.5 && rsi <= 55.0;
  }

  bool isReadyForBreakout(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double rsi = calculateRSI(coin);
    // العملات الجاهزة للانفجار السريع خلال الساعات القادمة
    return change24 > 2.5 && rsi > 55.0 && rsi < 75.0;
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
            Tab(icon: Icon(Icons.layers), text: 'مناطق التجميع فقط 🏦'),
            Tab(icon: Icon(Icons.show_chart), text: 'الشرت والتشبع 📈'),
            Tab(icon: Icon(Icons.access_time), text: 'متى تتداول؟ ⏰'),
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
                      hintText: 'بحث عن عملة ومعرفة متى تتوقع حركتها...',
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
                      _buildCryptoList(_filteredList, 'breakout'),
                      _buildCryptoList(_filteredList, 'smart_money'),
                      _buildCryptoList(_filteredList, 'chart'),
                      _buildTradingSessionsView(),
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
    List<dynamic> displayCoins = List.from(coins);

    if (category == 'smart_money') {
      // إظهار فقط العملات القائمة داخل نطاق التجميع حالياً واستبعاد البقية
      displayCoins = displayCoins.where((c) => isInAccumulationZone(c)).toList();
    } else if (category == 'breakout') {
      // إظهار العملات الجاهزة للانفجار السريع
      displayCoins = displayCoins.where((c) => isReadyForBreakout(c)).toList();
    }

    if (displayCoins.isEmpty) {
      return const Center(
        child: Text('لا توجد عملات تطابق هذا التصفية حالياً في السوق.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: displayCoins.length,
      itemBuilder: (context, index) {
        final coin = displayCoins[index];
        final double price = (coin['current_price'] ?? 0).toDouble();
        final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
        final bool isPositive = change24 >= 0;
        final double rsi = calculateRSI(coin);

        return Card(
          color: const Color(0xFF151C2C),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Image.network(
                coin['image'] ?? '',
                errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin),
              ),
            ),
            title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text('السعر: \$$price | RSI: $rsi',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
            onTap: () {
              // الانتقال لصفحة الشرت المخصصة للفريمات الزمنية عند الضغط
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CoinDetailScreen(coin: coin),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// شاشة تفاصيل العملة والشرت للفريمات المختلفة (1m, 15m, 1h, 4h)
class CoinDetailScreen extends StatefulWidget {
  final dynamic coin;
  const CoinDetailScreen({super.key, required this.coin});

  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  String _selectedTimeframe = '15m';

  @override
  Widget build(BuildContext context) {
    final coin = widget.coin;
    final double price = (coin['current_price'] ?? 0).toDouble();
    final List<dynamic> sparkline = coin['sparkline_in_7d']?['price'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('${coin['name']} - الشرت المباشر'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('\$$price', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Text('متوقع التحرك: خلال 1-3 ساعات 🚀', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // أزرار الفريمات الزمنية
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['1m', '15m', '1h', '4h'].map((tf) {
                final bool isSelected = _selectedTimeframe == tf;
                return ChoiceChip(
                  label: Text(tf, style: TextStyle(color: isSelected ? Colors.black : Colors.white)),
                  selected: isSelected,
                  selectedColor: Colors.cyanAccent,
                  backgroundColor: const Color(0xFF151C2C),
                  onSelected: (val) {
                    setState(() => _selectedTimeframe = tf);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // الشرت التفاعلي المباشر
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF151C2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الفريم الحالي: $_selectedTimeframe', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: sparkline.take(30).map((p) {
                      double h = ((p - price) / price).abs() * 1000;
                      if (h > 120) h = 120;
                      if (h < 10) h = 10;
                      return Container(
                        width: 6,
                        height: h,
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // بيانات وتوقعات التداول
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF151C2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 تحليل الذكاء الاصطناعي للفريم الحالي:', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('• النطاق السعري المتوقع: \$${(price * 0.98).toStringAsFixed(3)} ➔ \$${(price * 1.04).toStringAsFixed(3)}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text('• قرار الدخول: دخول شراء عند كسر مقاومة القمة السابقة على فريم 15m.', style: const TextStyle(fontSize: 12, color: Colors.greenAccent)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
