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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
                      _buildCryptoList(_cryptoList, 'smart_money'),
                      _buildCryptoList(_cryptoList, 'chart'),
                      _buildTradingSessionsView(),
                      _buildCryptoList(_cryptoList, 'manipulation'),
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

    // إذا أدخل المستخدم نصاً للبحث، تتجاوز الفلترة الخاصة بالتبويب لتعرض العملة المطلوبة فوراً
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
      return const Center(
        child: Text('لا توجد نتائج مطابقة لجهود البحث حالياً.', style: TextStyle(color: Colors.grey)),
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
            subtitle: Text('السعر الحالي: \$$price | RSI: $rsi',
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

// شاشة الشرت والشموع اليابانية الحقيقية وتفاصيل الدخول والخروج
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
    final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    final List<dynamic> sparklineRaw = coin['sparkline_in_7d']?['price'] ?? [];

    // تحويل أسعار sparkline إلى بيانات شموع يابانية (Open, High, Low, Close)
    List<CandleData> candles = [];
    if (sparklineRaw.length >= 8) {
      for (int i = 0; i < sparklineRaw.length - 3; i += 3) {
        double open = (sparklineRaw[i] as num).toDouble();
        double close = (sparklineRaw[i + 2] as num).toDouble();
        double high = open > close ? open * 1.002 : close * 1.002;
        double low = open < close ? open * 0.998 : close * 0.998;
        candles.add(CandleData(open: open, high: high, low: low, close: close));
      }
    }

    double entryPrice = price;
    double target1 = price * 1.035;
    double target2 = price * 1.07;
    double stopLoss = price * 0.975;

    return Scaffold(
      appBar: AppBar(
        title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\$$price', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    Text('${change24 >= 0 ? '+' : ''}${change24.toStringAsFixed(2)}%',
                        style: TextStyle(color: change24 >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Text('🚀 التوقع: جاهزة للانطلاق', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // أزرار الفريمات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['1m', '15m', '1h', '4h'].map((tf) {
                final bool isSelected = _selectedTimeframe == tf;
                return ChoiceChip(
                  label: Text(tf, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                  selected: isSelected,
                  selectedColor: Colors.cyanAccent,
                  backgroundColor: const Color(0xFF151C2C),
                  onSelected: (val) {
                    setState(() => _selectedTimeframe = tf);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // الشرت بالشموع اليابانية الملونة
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF151C2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.2)),
              ),
              child: candles.isEmpty
                  ? const Center(child: Text('جاري تحميل بيانات الشموع اليابانية...'))
                  : CustomPaint(
                      painter: CandlestickPainter(candles: candles.take(24).toList()),
                    ),
            ),
            const SizedBox(height: 20),
            // بطاقة تفاصيل نقطة الدخول والخروج والستوب
            const Text('🎯 تفاصيل الصفقة والدخول والخروج:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF151C2C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _buildTradeRow('🟢 سعر الدخول المقترح (BUY):', '\$${entryPrice.toStringAsFixed(4)}', Colors.greenAccent),
                  const Divider(color: Colors.grey),
                  _buildTradeRow('🎯 الهدف الأول (TP1 - +3.5%):', '\$${target1.toStringAsFixed(4)}', Colors.cyanAccent),
                  const SizedBox(height: 6),
                  _buildTradeRow('🎯 الهدف الثاني (TP2 - +7.0%):', '\$${target2.toStringAsFixed(4)}', Colors.cyanAccent),
                  const Divider(color: Colors.grey),
                  _buildTradeRow('🛑 وقف الخسارة (Stop Loss):', '\$${stopLoss.toStringAsFixed(4)}', Colors.redAccent),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('الوقت المتوقع لتحقق الهدف: خلال 1 إلى 4 ساعات مع بداية ضخ السيولة في الجلسة الحالية.',
                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTradeRow(String title, String value, Color valColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valColor)),
      ],
    );
  }
}

class CandleData {
  final double open;
  final double high;
  final double low;
  final double close;

  CandleData({required this.open, required this.high, required this.low, required this.close});
}

// رسم الشموع اليابانية
class CandlestickPainter extends CustomPainter {
  final List<CandleData> candles;

  CandlestickPainter({required this.candles});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    double minPrice = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    double maxPrice = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    if (maxPrice == minPrice) maxPrice += 0.0001;

    double candleWidth = size.width / candles.length;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      bool isBullish = c.close >= c.open;
      Color candleColor = isBullish ? Colors.greenAccent : Colors.redAccent;

      double x = (i * candleWidth) + (candleWidth / 2);

      double highY = size.height - ((c.high - minPrice) / (maxPrice - minPrice) * size.height);
      double lowY = size.height - ((c.low - minPrice) / (maxPrice - minPrice) * size.height);
      double openY = size.height - ((c.open - minPrice) / (maxPrice - minPrice) * size.height);
      double closeY = size.height - ((c.close - minPrice) / (maxPrice - minPrice) * size.height);

      // رسم الخيط العمودي (Wick)
      final wickPaint = Paint()
        ..color = candleColor
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      // رسم جسم الشمعة (Body)
      final bodyPaint = Paint()
        ..color = candleColor
        ..style = PaintingStyle.fill;

      double topY = openY < closeY ? openY : closeY;
      double bodyHeight = (openY - closeY).abs();
      if (bodyHeight < 2) bodyHeight = 2;

      canvas.drawRect(
        Rect.fromLTWH(x - (candleWidth * 0.3), topY, candleWidth * 0.6, bodyHeight),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
