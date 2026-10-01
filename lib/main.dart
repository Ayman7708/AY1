import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Ayman7708App());
}

class Ayman7708App extends StatelessWidget {
  const Ayman7708App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ayman7708',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF151922),
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
  bool _isLoading = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> _activeTrades = [];
  List<Map<String, dynamic>> _tradeHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSavedData();
    fetchLiveMarketData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? activeJson = prefs.getString('active_trades');
    final String? historyJson = prefs.getString('trade_history');

    setState(() {
      if (activeJson != null) {
        _activeTrades = List<Map<String, dynamic>>.from(json.decode(activeJson));
      }
      if (historyJson != null) {
        _tradeHistory = List<Map<String, dynamic>>.from(json.decode(historyJson));
      }
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_trades', json.encode(_activeTrades));
    await prefs.setString('trade_history', json.encode(_tradeHistory));
  }

  Future<void> fetchLiveMarketData() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=true');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _cryptoList = data;
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

  bool isEntryValid(dynamic coin) {
    double rsi = calculateRSI(coin);
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    return rsi <= 68.0 && change24 >= -4.0;
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
        'entryTime': DateTime.now().toIso8601String(),
        'image': coin['image'],
      });
    });
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('🎯 تم تفعيل الصفقة وحفظها لـ ${coin['name']}!'),
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
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.candlestick_chart, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('Ayman7708 Pro Chart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amberAccent),
            onPressed: fetchLiveMarketData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.rocket_launch), text: 'انفجار قريب 🚀'),
            Tab(icon: Icon(Icons.track_changes), text: 'صفقاتي النشطة 🎯'),
            Tab(icon: Icon(Icons.analytics), text: 'سجل وأرباح الصفقات 📊'),
            Tab(icon: Icon(Icons.show_chart), text: 'الشرت والشموع 📈'),
            Tab(icon: Icon(Icons.layers), text: 'مناطق التجميع فقط 🏦'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextField(
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'بحث في جميع العملات الرقمية (BTC, FET, PEPE)...',
                      prefixIcon: const Icon(Icons.search, color: Colors.amberAccent),
                      filled: true,
                      fillColor: const Color(0xFF151922),
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
                      _buildCryptoList(_cryptoList, 'chart'),
                      _buildCryptoList(_cryptoList, 'smart_money'),
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
        child: Text('لا توجد صفقات نشطة حالياً.\nادخل في صفقة من قائمة العملات وسيتم حفظها أوتوماتيكياً!',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: _activeTrades.length,
      itemBuilder: (context, index) {
        final trade = _activeTrades[index];
        return Card(
          color: const Color(0xFF151922),
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
                      child: const Text('🔒 صفقة نشطة', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('• سعر الدخول: \$${trade['entryPrice']}', style: const TextStyle(fontSize: 12)),
                Text('• الهدف الأول: \$${trade['targetPrice'].toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Colors.amberAccent)),
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
          const Text('📊 سجل الأرباح ونسبة نجاح التداول الدائمة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('إجمالي الصفقات', '$totalTrades', Colors.amberAccent),
              _buildStatCard('الناجحة', '$wins', Colors.greenAccent),
              _buildStatCard('الخاسرة', '$losses', Colors.redAccent),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF151922),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text('نسبة النجاح الكلية (Win Rate):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Text('${winRate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
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
        color: const Color(0xFF151922),
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
      return const Center(child: Text('لا توجد نتائج مطابقة لبحثك.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: displayCoins.length,
      itemBuilder: (context, index) {
        final coin = displayCoins[index];
        final double price = (coin['current_price'] ?? 0).toDouble();
        final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
        final bool isPositive = change24 >= 0;
        final double rsi = calculateRSI(coin);
        final bool validEntry = isEntryValid(coin);

        final bool isAlreadyInTrade = _activeTrades.any((t) => t['id'] == coin['id']);

        return Card(
          color: const Color(0xFF151922),
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
            title: Row(
              children: [
                Expanded(
                  child: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: validEntry ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: validEntry ? Colors.greenAccent : Colors.redAccent, width: 0.8),
                  ),
                  child: Text(
                    validEntry ? '🟢 صالحة للدخول' : '🔴 غير صالحة',
                    style: TextStyle(color: validEntry ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CoinDetailScreen(
                    coin: coin,
                    onTradeEntered: () => _enterTrade(coin),
                    isAlreadyInTrade: isAlreadyInTrade,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class CoinDetailScreen extends StatefulWidget {
  final dynamic coin;
  final VoidCallback onTradeEntered;
  final bool isAlreadyInTrade;

  const CoinDetailScreen({
    super.key,
    required this.coin,
    required this.onTradeEntered,
    required this.isAlreadyInTrade,
  });

  @override
  State<CoinDetailScreen> createState() => _CoinDetailScreenState();
}

class _CoinDetailScreenState extends State<CoinDetailScreen> {
  String _selectedTimeframe = '15m';

  List<CandleData> _generateCandlesWithEMA(List<dynamic> rawSparkline, String tf) {
    if (rawSparkline.isEmpty) return [];

    double mult = 1.0;
    if (tf == '1m') mult = 0.998;
    if (tf == '5m') mult = 0.999;
    if (tf == '15m') mult = 1.0;
    if (tf == '1h') mult = 1.002;
    if (tf == '4h') mult = 1.005;
    if (tf == '1d') mult = 1.01;

    List<CandleData> list = [];
    int step = tf == '1m' ? 1 : (tf == '5m' ? 2 : (tf == '15m' ? 3 : 4));

    for (int i = 0; i < rawSparkline.length - step; i += step) {
      double open = (rawSparkline[i] as num).toDouble() * mult;
      double close = (rawSparkline[i + step - 1] as num).toDouble();
      double high = (open > close ? open : close) * 1.0025;
      double low = (open < close ? open : close) * 0.9975;
      list.add(CandleData(open: open, high: high, low: low, close: close));
    }

    // حساب متوسطات EMA(7) و EMA(25) و EMA(99)
    for (int i = 0; i < list.length; i++) {
      list[i].ema7 = _calculateEMA(list, i, 7);
      list[i].ema25 = _calculateEMA(list, i, 25);
      list[i].ema99 = _calculateEMA(list, i, 99);
    }

    return list;
  }

  double _calculateEMA(List<CandleData> data, int index, int period) {
    double k = 2 / (period + 1);
    double ema = data[0].close;
    for (int i = 0; i <= index; i++) {
      ema = (data[i].close * k) + (ema * (1 - k));
    }
    return ema;
  }

  @override
  Widget build(BuildContext context) {
    final coin = widget.coin;
    final double price = (coin['current_price'] ?? 0).toDouble();
    final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    final List<dynamic> sparklineRaw = coin['sparkline_in_7d']?['price'] ?? [];

    List<CandleData> candles = _generateCandlesWithEMA(sparklineRaw, _selectedTimeframe);

    return Scaffold(
      appBar: AppBar(
        title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\$$price', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                    Text('${change24 >= 0 ? '+' : ''}${change24.toStringAsFixed(2)}%',
                        style: TextStyle(color: change24 >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: widget.isAlreadyInTrade ? Colors.grey : Colors.amberAccent),
                  icon: const Icon(Icons.flash_on, color: Colors.black),
                  label: Text(widget.isAlreadyInTrade ? 'قيد المراقبة' : 'دخول ومراقبة الصفقة', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  onPressed: widget.isAlreadyInTrade
                      ? null
                      : () {
                          widget.onTradeEntered();
                          Navigator.pop(context);
                        },
                )
              ],
            ),
            const SizedBox(height: 12),
            // أزرار اختيار الفريمات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['1m', '5m', '15m', '1h', '4h', '1d'].map((tf) {
                final bool isSelected = _selectedTimeframe == tf;
                return ChoiceChip(
                  label: Text(tf, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  selected: isSelected,
                  selectedColor: Colors.amberAccent,
                  backgroundColor: const Color(0xFF151922),
                  onSelected: (val) {
                    setState(() => _selectedTimeframe = tf);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            // تفاصيل مؤشرات EMA المفعّلة
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('EMA(7) ', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('EMA(25) ', style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('EMA(99)', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            // الشرت الاحترافي بالشموع اليابانية والمؤشرات
            Container(
              height: 300,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF151922),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: candles.isEmpty
                    ? const Center(child: Text('جاري تحميل الشموع والمؤشرات...'))
                    : CustomPaint(
                        key: ValueKey(_selectedTimeframe),
                        size: Size.infinite,
                        painter: BinanceStyleChartPainter(candles: candles.take(32).toList(), currentPrice: price),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CandleData {
  final double open;
  final double high;
  final double low;
  final double close;
  double ema7 = 0.0;
  double ema25 = 0.0;
  double ema99 = 0.0;

  CandleData({required this.open, required this.high, required this.low, required this.close});
}

class BinanceStyleChartPainter extends CustomPainter {
  final List<CandleData> candles;
  final double currentPrice;

  BinanceStyleChartPainter({required this.candles, required this.currentPrice});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    double minPrice = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    double maxPrice = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    if (maxPrice == minPrice) maxPrice += 0.0001;

    // رسم خطوط الشبكة للخلفية
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) {
      double y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double candleWidth = size.width / candles.length;

    List<Offset> ema7Points = [];
    List<Offset> ema25Points = [];
    List<Offset> ema99Points = [];

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      bool isBullish = c.close >= c.open;
      Color candleColor = isBullish ? const Color(0xFF0ECB81) : const Color(0xFFF6465D);

      double x = (i * candleWidth) + (candleWidth / 2);

      double highY = size.height - ((c.high - minPrice) / (maxPrice - minPrice) * size.height);
      double lowY = size.height - ((c.low - minPrice) / (maxPrice - minPrice) * size.height);
      double openY = size.height - ((c.open - minPrice) / (maxPrice - minPrice) * size.height);
      double closeY = size.height - ((c.close - minPrice) / (maxPrice - minPrice) * size.height);

      // فتيل الشمعة
      final wickPaint = Paint()
        ..color = candleColor
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      // جسم الشمعة
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

      // حصر نقاط EMA
      double ema7Y = size.height - ((c.ema7 - minPrice) / (maxPrice - minPrice) * size.height);
      double ema25Y = size.height - ((c.ema25 - minPrice) / (maxPrice - minPrice) * size.height);
      double ema99Y = size.height - ((c.ema99 - minPrice) / (maxPrice - minPrice) * size.height);

      ema7Points.add(Offset(x, ema7Y));
      ema25Points.add(Offset(x, ema25Y));
      ema99Points.add(Offset(x, ema99Y));
    }

    // رسم منحنيات الـ EMA
    _drawLines(canvas, ema7Points, Colors.amberAccent);
    _drawLines(canvas, ema25Points, Colors.purpleAccent);
    _drawLines(canvas, ema99Points, Colors.cyanAccent);

    // رسم خط السعر المباشر المنقط
    double currentPriceY = size.height - ((currentPrice - minPrice) / (maxPrice - minPrice) * size.height);
    final priceLinePaint = Paint()
      ..color = Colors.amberAccent.withOpacity(0.6)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, currentPriceY), Offset(size.width, currentPriceY), priceLinePaint);
  }

  void _drawLines(Canvas canvas, List<Offset> points, Color color) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
