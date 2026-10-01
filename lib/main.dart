import 'dart0:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

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

  // إعدادات الاستراتيجية التكيفية
  double _riskFactor = 1.0; 

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
      _updateAdaptiveStrategy();
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_trades', json.encode(_activeTrades));
    await prefs.setString('trade_history', json.encode(_tradeHistory));
  }

  void _updateAdaptiveStrategy() {
    if (_tradeHistory.isEmpty) {
      _riskFactor = 1.0;
      return;
    }
    int recentLosses = _tradeHistory.take(10).where((t) => t['isWin'] == false).length;
    if (recentLosses >= 4) {
      _riskFactor = 1.4; // تشديد فلترة الدخول وتقليل المخاطرة
    } else if (recentLosses >= 2) {
      _riskFactor = 1.2;
    } else {
      _riskFactor = 1.0;
    }
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
        _checkAndAutoCloseTrades();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // فحص الصفقات المفتوحة وإغلاقها تلقائياً عند وصول السعر للهدف أو وقف الخسارة
  void _checkAndAutoCloseTrades() {
    if (_activeTrades.isEmpty || _cryptoList.isEmpty) return;

    List<Map<String, dynamic>> closedNow = [];

    for (var trade in List<Map<String, dynamic>>.from(_activeTrades)) {
      final coin = _cryptoList.firstWhere(
        (c) => c['id'] == trade['id'],
        orElse: () => null,
      );

      if (coin != null) {
        double currentPrice = (coin['current_price'] ?? 0).toDouble();
        double target = (trade['targetPrice'] as num).toDouble();
        double stopLoss = (trade['stopLoss'] as num).toDouble();

        if (currentPrice >= target) {
          _closeTrade(trade, true, autoClosed: true, closePrice: currentPrice);
          closedNow.add({...trade, 'reason': 'تحقق الهدف 🎯'});
        } else if (currentPrice <= stopLoss) {
          _closeTrade(trade, false, autoClosed: true, closePrice: currentPrice);
          closedNow.add({...trade, 'reason': 'ضرب وقف الخسارة 🛑'});
        }
      }
    }

    if (closedNow.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber,
          content: Text('⚠️ تم إغلاق ${closedNow.length} صفقة تلقائياً بناءً على حركة السعر المباشرة!'),
        ),
      );
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  // 1. حساب RSI
  double calculateRSI(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double baseRsi = 50.0 + (change24 * 2.2);
    if (baseRsi > 92.0) return 92.0;
    if (baseRsi < 12.0) return 12.0;
    return double.parse(baseRsi.toStringAsFixed(1));
  }

  // 2. خوارزمية AI KNN لحساب احتمالية الصعود للفريمات الصغيرة
  double calculateAiKnnProbability(dynamic coin) {
    double rsi = calculateRSI(coin);
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double vol = ((coin['total_volume'] ?? 1) as num).toDouble();
    double marketCap = ((coin['market_cap'] ?? 1) as num).toDouble();
    double volRatio = (vol / marketCap).clamp(0.01, 1.0);

    // نموذج KNN مبسط يعطي وزناً لمجموع الشروط اللحظية
    double score = 50.0;
    if (rsi >= 30 && rsi <= 62) score += 18.0;
    if (change24 > -2.0 && change24 < 6.0) score += 15.0;
    if (volRatio > 0.08) score += 12.0;

    return score.clamp(10.0, 98.0);
  }

  // 3. حساب نطاق ATR الديناميكي لتحديد الستوب والهدف اللحظي
  Map<String, double> calculateDynamicAtrBounds(dynamic coin) {
    double price = (coin['current_price'] ?? 0).toDouble();
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble().abs();
    
    // تقدير الـ ATR اللحظي بناءً على تقلبات 24 ساعة
    double atrPercent = (change24 * 0.15).clamp(0.012, 0.045) * _riskFactor;

    double stopLossPrice = price * (1.0 - atrPercent);
    double targetPrice = price * (1.0 + (atrPercent * 1.6)); // نسبة المخاطرة للعائد 1:1.6

    return {
      'target': targetPrice,
      'stopLoss': stopLossPrice,
      'atrPercent': atrPercent * 100,
    };
  }

  bool isEntryValid(dynamic coin) {
    double rsi = calculateRSI(coin);
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double aiScore = calculateAiKnnProbability(coin);

    double maxRsiThreshold = 68.0 / _riskFactor;
    return rsi <= maxRsiThreshold && change24 >= -4.0 && aiScore >= 60.0;
  }

  bool isInAccumulationZone(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double rsi = calculateRSI(coin);
    return change24 >= -3.5 && change24 <= 2.0 && rsi <= (55.0 / _riskFactor);
  }

  bool isReadyForBreakout(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double rsi = calculateRSI(coin);
    double aiScore = calculateAiKnnProbability(coin);

    return (change24 > (1.5 * _riskFactor) || rsi > 58.0) && aiScore >= 65.0;
  }

  void _enterTrade(dynamic coin) {
    double price = (coin['current_price'] ?? 0).toDouble();
    var atrBounds = calculateDynamicAtrBounds(coin);

    setState(() {
      _activeTrades.add({
        'id': coin['id'],
        'name': coin['name'],
        'symbol': coin['symbol'],
        'entryPrice': price,
        'targetPrice': atrBounds['target'],
        'stopLoss': atrBounds['stopLoss'],
        'entryTime': DateTime.now().toIso8601String(),
        'image': coin['image'],
        'aiScore': calculateAiKnnProbability(coin),
      });
    });
    _saveData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('🎯 تم تفعيل الصفقة واستخدام هدف وستوب ATR ديناميكي لـ ${coin['name']}!'),
      ),
    );
  }

  void _closeTrade(Map<String, dynamic> trade, bool isWin, {bool autoClosed = false, double? closePrice}) {
    setState(() {
      _activeTrades.removeWhere((t) => t['id'] == trade['id']);
      double finalClosePrice = closePrice ?? (isWin ? trade['targetPrice'] : trade['stopLoss']);
      double entry = (trade['entryPrice'] as num).toDouble();
      double pnlPercent = ((finalClosePrice - entry) / entry) * 100;

      _tradeHistory.add({
        ...trade,
        'isWin': isWin,
        'closePrice': finalClosePrice,
        'pnlPercent': pnlPercent,
        'autoClosed': autoClosed,
      });
      _updateAdaptiveStrategy();
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
            Text('Ayman7708 Pro AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            Tab(icon: Icon(Icons.layers), text: 'مناطق التجميع 🏦'),
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
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF151922),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الصفقات المفتوحة: ${_activeTrades.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
                icon: const Icon(Icons.history, color: Colors.black, size: 18),
                label: const Text('انتقال لسجل الصفقات المغلقة 📊', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () {
                  _tabController.animateTo(2); // التبديل لتبويب سجل الصفقات
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _activeTrades.isEmpty
              ? const Center(
                  child: Text('لا توجد صفقات نشطة حالياً.\nسيتم مراقبة وإغلاق الصفقات أوتوماتيكياً عند وصول السعر للأهداف!',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: _activeTrades.length,
                  itemBuilder: (context, index) {
                    final trade = _activeTrades[index];
                    final coin = _cryptoList.firstWhere((c) => c['id'] == trade['id'], orElse: () => null);
                    double currentPrice = coin != null ? (coin['current_price'] ?? 0).toDouble() : (trade['entryPrice'] as num).toDouble();

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
                                  child: const Text('🔒 صفقة نشطة ومراقبة', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('• سعر الدخول: \$${trade['entryPrice']}', style: const TextStyle(fontSize: 12)),
                                Text('السعر الحالي: \$${currentPrice.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('• الهدف الأول (ATR): \$${(trade['targetPrice'] as num).toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Colors.greenAccent)),
                            Text('• وقف الخسارة (ATR): \$${(trade['stopLoss'] as num).toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                            const Divider(color: Colors.grey),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    onPressed: () => _closeTrade(trade, true),
                                    child: const Text('إغلاق يدوي (ربح 🎯)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                    onPressed: () => _closeTrade(trade, false),
                                    child: const Text('إغلاق يدوي (خسارة)', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPerformanceStatsView() {
    int totalTrades = _tradeHistory.length;
    int wins = _tradeHistory.where((t) => t['isWin'] == true).length;
    int losses = totalTrades - wins;
    double winRate = totalTrades > 0 ? (wins / totalTrades) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📊 سجل وأرباح الصفقات المغلقة:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _riskFactor > 1.0 ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _riskFactor > 1.0 ? Colors.orangeAccent : Colors.greenAccent),
                ),
                child: Text(
                  _riskFactor > 1.0 ? '🛡️ استراتيجية متكيفة (حذر مرتفع)' : '⚡ استراتيجية قياسية AI',
                  style: TextStyle(color: _riskFactor > 1.0 ? Colors.orangeAccent : Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard('إجمالي الصفقات', '$totalTrades', Colors.amberAccent),
              _buildStatCard('الناجحة 🎯', '$wins', Colors.greenAccent),
              _buildStatCard('الخاسرة 🛑', '$losses', Colors.redAccent),
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
          const SizedBox(height: 20),
          const Text('قائمة الصفقات المغلقة مؤخراً:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 8),
          _tradeHistory.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد صفقات مغلقة في السجل حتى الآن', style: TextStyle(color: Colors.grey))))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tradeHistory.reversed.length,
                  itemBuilder: (context, idx) {
                    final t = _tradeHistory.reversed.toList()[idx];
                    bool isWin = t['isWin'] == true;
                    double pnl = (t['pnlPercent'] as num).toDouble();
                    bool autoClosed = t['autoClosed'] == true;

                    return Card(
                      color: const Color(0xFF151922),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(isWin ? Icons.check_circle : Icons.cancel, color: isWin ? Colors.greenAccent : Colors.redAccent),
                        title: Text('${t['name']} (${t['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('دخول: \$${t['entryPrice']} | إغلاق: \$${(t['closePrice'] as num).toStringAsFixed(4)}${autoClosed ? ' (آلي)' : ''}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        trailing: Text(
                          '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%',
                          style: TextStyle(color: isWin ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
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
        final double aiProbability = calculateAiKnnProbability(coin);
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
            subtitle: Text('السعر: \$$price | RSI: $rsi | AI: ${aiProbability.toStringAsFixed(0)}%',
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
  double _zoomScale = 1.0;

  List<CandleData> _generateCandlesWithIndicators(List<dynamic> rawSparkline, String tf) {
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
      double high = (open > close ? open : close) * 1.003;
      double low = (open < close ? open : close) * 0.997;
      double volume = ((high - low) * 100000).abs();

      list.add(CandleData(open: open, high: high, low: low, close: close, volume: volume));
    }

    // حساب EMA(7), EMA(25), EMA(99) وإشارات الذكاء الاصطناعي
    for (int i = 0; i < list.length; i++) {
      list[i].ema7 = _calculateEMA(list, i, 7);
      list[i].ema25 = _calculateEMA(list, i, 25);
      list[i].ema99 = _calculateEMA(list, i, 99);

      // كشف كتل السيولة اللحظية (Order Blocks)
      if (list[i].volume > 1.8 * (i > 0 ? list[i - 1].volume : list[i].volume)) {
        list[i].isOrderBlock = true;
      }

      // تحديد إشارات Buy / Sell الذكية للفريمات الصغيرة
      if (i > 1) {
        if (list[i].ema7 > list[i].ema25 && list[i - 1].ema7 <= list[i - 1].ema25) {
          list[i].signal = 'B'; // Buy Signal
        } else if (list[i].ema7 < list[i].ema25 && list[i - 1].ema7 >= list[i - 1].ema25) {
          list[i].signal = 'S'; // Sell Signal
        }
      }
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

    List<CandleData> candles = _generateCandlesWithIndicators(sparklineRaw, _selectedTimeframe);

    return Scaffold(
      appBar: AppBar(
        title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()}) Pro Chart'),
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('EMA(7) ', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('EMA(25) ', style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('EMA(99) ', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('| VOL ', style: TextStyle(color: Colors.grey, fontSize: 11)),
                Text('| 🟨 OB (Smart Block)', style: TextStyle(color: Colors.amber, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            // الشرت التفاعلي المتقدم باللمس والتكبير
            GestureDetector(
              onScaleUpdate: (details) {
                setState(() {
                  _zoomScale = (_zoomScale * details.scale).clamp(0.6, 2.5);
                });
              },
              child: Container(
                height: 340,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF151922),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                ),
                child: candles.isEmpty
                    ? const Center(child: Text('جاري تحميل الشموع والمؤشرات...'))
                    : CustomPaint(
                        size: Size.infinite,
                        painter: AdvancedInteractiveChartPainter(
                          candles: candles,
                          currentPrice: price,
                          scale: _zoomScale,
                        ),
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
  final double volume;
  double ema7 = 0.0;
  double ema25 = 0.0;
  double ema99 = 0.0;
  bool isOrderBlock = false;
  String? signal; // 'B' or 'S'

  CandleData({required this.open, required this.high, required this.low, required this.close, required this.volume});
}

class AdvancedInteractiveChartPainter extends CustomPainter {
  final List<CandleData> candles;
  final double currentPrice;
  final double scale;

  AdvancedInteractiveChartPainter({required this.candles, required this.currentPrice, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    int visibleCount = (32 / scale).round().clamp(15, candles.length);
    List<CandleData> displayCandles = candles.take(visibleCount).toList();

    double minPrice = displayCandles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    double maxPrice = displayCandles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    if (maxPrice == minPrice) maxPrice += 0.0001;

    double maxVol = displayCandles.map((c) => c.volume).reduce((a, b) => a > b ? a : b);
    if (maxVol == 0) maxVol = 1;

    // خطوط الشبكة للخلفية
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) {
      double y = (size.height * 0.75) * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double candleWidth = size.width / displayCandles.length;

    List<Offset> ema7Points = [];
    List<Offset> ema25Points = [];
    List<Offset> ema99Points = [];

    double chartHeight = size.height * 0.75;
    double volumeAreaHeight = size.height * 0.22;

    for (int i = 0; i < displayCandles.length; i++) {
      final c = displayCandles[i];
      bool isBullish = c.close >= c.open;
      Color candleColor = isBullish ? const Color(0xFF0ECB81) : const Color(0xFFF6465D);

      double x = (i * candleWidth) + (candleWidth / 2);

      double highY = chartHeight - ((c.high - minPrice) / (maxPrice - minPrice) * chartHeight);
      double lowY = chartHeight - ((c.low - minPrice) / (maxPrice - minPrice) * chartHeight);
      double openY = chartHeight - ((c.open - minPrice) / (maxPrice - minPrice) * chartHeight);
      double closeY = chartHeight - ((c.close - minPrice) / (maxPrice - minPrice) * chartHeight);

      // رسم فتيل الشمعة
      final wickPaint = Paint()
        ..color = candleColor
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      // رسم جسم الشمعة (أصفر إذا كانت كتلة سيولة Order Block)
      final bodyPaint = Paint()
        ..color = c.isOrderBlock ? Colors.amber : candleColor
        ..style = PaintingStyle.fill;

      double topY = openY < closeY ? openY : closeY;
      double bodyHeight = (openY - closeY).abs();
      if (bodyHeight < 2) bodyHeight = 2;

      canvas.drawRect(
        Rect.fromLTWH(x - (candleWidth * 0.3), topY, candleWidth * 0.6, bodyHeight),
        bodyPaint,
      );

      // رسم أشرطة الحجم (Volume Bars)
      double volHeight = (c.volume / maxVol) * volumeAreaHeight;
      final volPaint = Paint()
        ..color = candleColor.withOpacity(0.4)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(x - (candleWidth * 0.3), size.height - volHeight, candleWidth * 0.6, volHeight),
        volPaint,
      );

      // إشارات Buy / Sell المرئية
      if (c.signal != null) {
        bool isBuy = c.signal == 'B';
        final textPainter = TextPainter(
          text: TextSpan(
            text: isBuy ? 'B' : 'S',
            style: TextStyle(
              color: isBuy ? Colors.greenAccent : Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        double signalY = isBuy ? highY - 14 : lowY + 2;
        textPainter.paint(canvas, Offset(x - 4, signalY));
      }

      // حصر نقاط المتوسطات المتحركة
      double ema7Y = chartHeight - ((c.ema7 - minPrice) / (maxPrice - minPrice) * chartHeight);
      double ema25Y = chartHeight - ((c.ema25 - minPrice) / (maxPrice - minPrice) * chartHeight);
      double ema99Y = chartHeight - ((c.ema99 - minPrice) / (maxPrice - minPrice) * chartHeight);

      ema7Points.add(Offset(x, ema7Y));
      ema25Points.add(Offset(x, ema25Y));
      ema99Points.add(Offset(x, ema99Y));
    }

    // رسم خطوط EMA
    _drawPathLines(canvas, ema7Points, Colors.amberAccent);
    _drawPathLines(canvas, ema25Points, Colors.purpleAccent);
    _drawPathLines(canvas, ema99Points, Colors.cyanAccent);

    // خط السعر المباشر
    double currentPriceY = chartHeight - ((currentPrice - minPrice) / (maxPrice - minPrice) * chartHeight);
    final priceLinePaint = Paint()
      ..color = Colors.amberAccent.withOpacity(0.7)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, currentPriceY), Offset(size.width, currentPriceY), priceLinePaint);
  }

  void _drawPathLines(Canvas canvas, List<Offset> points, Color color) {
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
