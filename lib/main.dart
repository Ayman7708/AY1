import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      title: 'Ayman7708 Trading Bot',
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

  List<Map<String, dynamic>> _activeTrades = [];
  List<Map<String, dynamic>> _tradeHistory = [];

  bool _isAutoTradingEnabled = true;
  bool _isLiveRealFunds = false; 
  String _binanceApiKey = '';
  String _binanceApiSecret = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadSavedData();
    fetchLiveMarketData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? activeJson = prefs.getString('active_trades');
    final String? historyJson = prefs.getString('trade_history');
    
    _isAutoTradingEnabled = prefs.getBool('auto_trading') ?? true;
    _isLiveRealFunds = prefs.getBool('live_real_funds') ?? false;
    _binanceApiKey = prefs.getString('binance_key') ?? '';
    _binanceApiSecret = prefs.getString('binance_secret') ?? '';

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
    await prefs.setBool('auto_trading', _isAutoTradingEnabled);
    await prefs.setBool('live_real_funds', _isLiveRealFunds);
    await prefs.setString('binance_key', _binanceApiKey);
    await prefs.setString('binance_secret', _binanceApiSecret);
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
        _processAutoTradingEngine();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _processAutoTradingEngine() {
    if (_cryptoList.isEmpty) return;

    List<Map<String, dynamic>> updatedActive = [];

    for (var trade in List<Map<String, dynamic>>.from(_activeTrades)) {
      final coin = _cryptoList.firstWhere(
        (c) => c['id'] == trade['id'],
        orElse: () => null,
      );

      if (coin != null) {
        double currentPrice = (coin['current_price'] ?? 0).toDouble();
        double entry = (trade['entryPrice'] as num).toDouble();
        double tp1 = (trade['tp1'] as num).toDouble();
        double tp2 = (trade['tp2'] as num).toDouble();
        double tp3 = (trade['tp3'] as num).toDouble();
        int achievedTps = trade['achievedTps'] ?? 0;

        if (currentPrice >= tp1 && achievedTps < 1) {
          trade['stopLoss'] = entry * 1.002;
          trade['achievedTps'] = 1;
        } else if (currentPrice >= tp2 && achievedTps < 2) {
          trade['stopLoss'] = tp1;
          trade['achievedTps'] = 2;
        } else if (currentPrice >= tp3) {
          _closeTrade(trade, true, closePrice: tp3);
          continue;
        }

        if (currentPrice <= (trade['stopLoss'] as num).toDouble()) {
          bool isWinTrade = currentPrice > entry;
          _closeTrade(trade, isWinTrade, closePrice: (trade['stopLoss'] as num).toDouble());
          continue;
        }

        updatedActive.add(trade);
      } else {
        updatedActive.add(trade);
      }
    }

    _activeTrades = updatedActive;

    if (_isAutoTradingEnabled) {
      for (var coin in _cryptoList) {
        double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
        double rsi = calculateRSI(coin);
        
        if (change24 >= 2.5 && rsi >= 52.0 && rsi <= 68.0) {
          int activeSameCoin = _activeTrades.where((t) => t['id'] == coin['id']).length;

          if (activeSameCoin < 2) {
            _executeAutoTradeEntry(coin, activeSameCoin + 1);
          }
        }
      }
    }

    _saveData();
    if (mounted) setState(() {});
  }

  void _executeAutoTradeEntry(dynamic coin, int waveIndex) {
    double price = (coin['current_price'] ?? 0).toDouble();

    double tp1 = price * 1.012; 
    double tp2 = price * 1.028; 
    double tp3 = price * 1.045; 
    double stopLoss = price * 0.988;

    var newTrade = {
      'id': coin['id'],
      'name': coin['name'],
      'symbol': coin['symbol'],
      'entryPrice': price,
      'tp1': tp1,
      'tp2': tp2,
      'tp3': tp3,
      'stopLoss': stopLoss,
      'achievedTps': 0,
      'waveIndex': waveIndex,
      'entryTime': DateTime.now().toIso8601String(),
      'image': coin['image'],
      'leverage': 50.0,
      'isReal': _isLiveRealFunds,
      'isManual': false,
    };

    _activeTrades.add(newTrade);
  }

  // ميزة فتح صفقة يدوية مباشر
  void _openManualTradeDialog(dynamic coin) {
    double price = (coin['current_price'] ?? 0).toDouble();
    double lev = 50.0;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151922),
          title: Row(
            children: [
              if (coin['image'] != null) Image.network(coin['image'], width: 24, height: 24, errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin)),
              const SizedBox(width: 8),
              Text('فتح صفقة: ${coin['name']}', style: const TextStyle(fontSize: 16, color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('سعر الدخول المباشر: \$$price', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('الأهداف التلقائية (حساب آلي):', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('• Target 1: \$${(price * 1.012).toStringAsFixed(4)} (+1.2%)', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              Text('• Target 2: \$${(price * 1.028).toStringAsFixed(4)} (+2.8%)', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              Text('• Target 3: \$${(price * 1.045).toStringAsFixed(4)} (+4.5%)', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              Text('• Stop Loss: \$${(price * 0.988).toStringAsFixed(4)} (-1.2%)', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
              onPressed: () {
                var manualTrade = {
                  'id': coin['id'],
                  'name': coin['name'],
                  'symbol': coin['symbol'],
                  'entryPrice': price,
                  'tp1': price * 1.012,
                  'tp2': price * 1.028,
                  'tp3': price * 1.045,
                  'stopLoss': price * 0.988,
                  'achievedTps': 0,
                  'waveIndex': 1,
                  'entryTime': DateTime.now().toIso8601String(),
                  'image': coin['image'],
                  'leverage': lev,
                  'isReal': _isLiveRealFunds,
                  'isManual': true,
                };
                setState(() {
                  _activeTrades.add(manualTrade);
                });
                _saveData();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم فتح صفقة يدوية لـ ${coin['name']} بنجاح! 🚀'), backgroundColor: Colors.green),
                );
              },
              child: const Text('تأكيد وفتح الصفقة ⚡', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  double calculateRSI(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double baseRsi = 50.0 + (change24 * 2.2);
    if (baseRsi > 92.0) return 92.0;
    if (baseRsi < 12.0) return 12.0;
    return double.parse(baseRsi.toStringAsFixed(1));
  }

  void _closeTrade(Map<String, dynamic> trade, bool isWin, {required double closePrice}) {
    _activeTrades.removeWhere((t) => t == trade);
    double entry = (trade['entryPrice'] as num).toDouble();
    double leverage = ((trade['leverage'] ?? 50.0) as num).toDouble();
    double pnl = (((closePrice - entry) / entry) * 100) * leverage;

    _tradeHistory.add({
      ...trade,
      'isWin': isWin,
      'closePrice': closePrice,
      'pnlPercent': pnl,
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Colors.amberAccent),
            SizedBox(width: 6),
            Text('Ayman7708 Trading Bot Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isAutoTradingEnabled ? Icons.play_circle_fill : Icons.pause_circle_filled, color: _isAutoTradingEnabled ? Colors.greenAccent : Colors.redAccent),
            onPressed: () {
              setState(() {
                _isAutoTradingEnabled = !_isAutoTradingEnabled;
              });
              _saveData();
            },
          ),
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
            Tab(icon: Icon(Icons.track_changes), text: 'صفقاتي النشطة 🎯'),
            Tab(icon: Icon(Icons.analytics), text: 'سجل وأرباح الصفقات 📊'),
            Tab(icon: Icon(Icons.flash_on), text: 'صفقات سريعة (فتح يدوي) ⚡'),
            Tab(icon: Icon(Icons.saved_search), text: 'البحث العميق 🔍'),
            Tab(icon: Icon(Icons.rocket_launch), text: 'انفجار قريب 🚀'),
            Tab(icon: Icon(Icons.layers), text: 'مناطق التجميع 🏦'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveTradesProView(),
                _buildPerformanceStatsProView(),
                _buildScalpingView(),
                DeepSearchTab(cryptoList: _cryptoList, onManualOpen: _openManualTradeDialog),
                _buildCryptoList(_cryptoList),
                _buildCryptoList(_cryptoList),
              ],
            ),
    );
  }

  Widget _buildActiveTradesProView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: const Color(0xFF151922),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: _isAutoTradingEnabled ? Colors.greenAccent : Colors.redAccent),
                  ),
                  const SizedBox(width: 8),
                  Text(_isAutoTradingEnabled ? 'المستشعر الآلي شغال ⚡' : 'المستشعر متوقف ⏸️', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Text('النشطة: ${_activeTrades.length} صفقات', style: const TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: _activeTrades.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد صفقات نشطة حالياً.\nيمكنك فتح صفقة يدوياً من قائمة (الصفقات السريعة ⚡)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  itemCount: _activeTrades.length,
                  itemBuilder: (context, index) {
                    final trade = _activeTrades[index];
                    final coin = _cryptoList.firstWhere((c) => c['id'] == trade['id'], orElse: () => null);
                    double currentPrice = coin != null ? (coin['current_price'] ?? 0).toDouble() : (trade['entryPrice'] as num).toDouble();
                    double entryPrice = (trade['entryPrice'] as num).toDouble();
                    
                    bool isWin = currentPrice >= entryPrice;
                    double currentPnl = (((currentPrice - entryPrice) / entryPrice) * 100) * 50.0;
                    int achievedTps = trade['achievedTps'] ?? 0;
                    bool isManual = trade['isManual'] ?? false;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151922),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isWin ? Colors.greenAccent.withOpacity(0.6) : Colors.redAccent.withOpacity(0.4), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    if (trade['image'] != null)
                                      Image.network(trade['image'], width: 22, height: 22, errorBuilder: (_, __, ___) => const Icon(Icons.monetization_on, size: 20)),
                                    const SizedBox(width: 8),
                                    Text('${trade['name']} (${trade['symbol'].toString().toUpperCase()})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                                    const SizedBox(width: 6),
                                    if (isManual)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('يدوية 🖐️', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isWin ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${currentPnl >= 0 ? '+' : ''}${currentPnl.toStringAsFixed(1)}%',
                                    style: TextStyle(color: isWin ? Colors.greenAccent : Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('سعر الدخول: \$$entryPrice', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                Text('السعر الحالي: \$${currentPrice.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildTpBadgePro('TP1 🎯', (trade['tp1'] as num).toDouble(), achievedTps >= 1),
                                const SizedBox(width: 6),
                                _buildTpBadgePro('TP2 🎯', (trade['tp2'] as num).toDouble(), achievedTps >= 2),
                                const SizedBox(width: 6),
                                _buildTpBadgePro('TP3 🎯', (trade['tp3'] as num).toDouble(), achievedTps >= 3),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 36,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                onPressed: () => _closeTrade(trade, isWin, closePrice: currentPrice),
                                child: const Text('إغلاق الصفقة فوراً', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
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

  Widget _buildTpBadgePro(String label, double val, bool isAchieved) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isAchieved ? Colors.greenAccent : const Color(0xFF0B0E14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isAchieved ? Colors.greenAccent : Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: isAchieved ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('\$${val.toStringAsFixed(3)}', style: TextStyle(fontSize: 9, color: isAchieved ? Colors.black : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceStatsProView() {
    int totalTrades = _tradeHistory.length;
    int wins = _tradeHistory.where((t) => t['isWin'] == true).length;
    int losses = totalTrades - wins;
    double winRate = totalTrades > 0 ? (wins / totalTrades) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📊 سجل الأداء والنتائج:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(80, 30)),
                icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.white),
                label: const Text('تصفير', style: TextStyle(fontSize: 11, color: Colors.white)),
                onPressed: () {
                  setState(() {
                    _tradeHistory.clear();
                  });
                  _saveData();
                },
              )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCardPro('الصفقات المغلقة', '$totalTrades', Colors.amberAccent),
              _buildStatCardPro('الرابحة 🎯', '$wins', Colors.greenAccent),
              _buildStatCardPro('الخاسرة 🛑', '$losses', Colors.redAccent),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amberAccent.withOpacity(0.3))),
            child: Column(
              children: [
                const Text('معدل النجاح الكلي (Win Rate):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                Text('${winRate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: winRate >= 50 ? Colors.greenAccent : Colors.orangeAccent)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _tradeHistory.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('سجل الصفقات فارغ حالياً', style: TextStyle(color: Colors.grey))))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tradeHistory.reversed.length,
                  itemBuilder: (context, idx) {
                    final t = _tradeHistory.reversed.toList()[idx];
                    bool isWin = t['isWin'] == true;
                    double pnl = (t['pnlPercent'] as num).toDouble();

                    return Card(
                      color: const Color(0xFF151922),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(isWin ? Icons.check_circle : Icons.cancel, color: isWin ? Colors.greenAccent : Colors.redAccent),
                        title: Text('${t['name']} (${t['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('دخول: \$${t['entryPrice']} | إغلاق: \$${(t['closePrice'] as num).toStringAsFixed(4)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        trailing: Text(
                          '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(1)}%',
                          style: TextStyle(color: isWin ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildStatCardPro(String title, String val, Color color) {
    return Expanded(
      child: Card(
        color: const Color(0xFF151922),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScalpingView() {
    return ListView.builder(
      itemCount: _cryptoList.length,
      itemBuilder: (context, index) {
        final coin = _cryptoList[index];
        final double price = (coin['current_price'] ?? 0).toDouble();
        final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();

        return Card(
          color: const Color(0xFF151922),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Image.network(coin['image'] ?? '', width: 26, height: 26, errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin)),
            title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('السعر: \$$price | 24h: ${change24 >= 0 ? '+' : ''}${change24.toStringAsFixed(2)}%', style: TextStyle(fontSize: 11, color: change24 >= 0 ? Colors.greenAccent : Colors.redAccent)),
            trailing: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, minimumSize: const Size(90, 32)),
              icon: const Icon(Icons.add_chart, size: 14, color: Colors.black),
              label: const Text('دخول ⚡', style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)),
              onPressed: () => _openManualTradeDialog(coin),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCryptoList(List<dynamic> coins) {
    return ListView.builder(
      itemCount: coins.length,
      itemBuilder: (context, index) {
        final coin = coins[index];
        return Card(
          color: const Color(0xFF151922),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: ListTile(
            title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text('السعر: \$${coin['current_price']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: IconButton(
              icon: const Icon(Icons.flash_on, color: Colors.amberAccent),
              onPressed: () => _openManualTradeDialog(coin),
            ),
          ),
        );
      },
    );
  }
}

class DeepSearchTab extends StatefulWidget {
  final List<dynamic> cryptoList;
  final Function(dynamic) onManualOpen;
  const DeepSearchTab({super.key, required this.cryptoList, required this.onManualOpen});

  @override
  State<DeepSearchTab> createState() => _DeepSearchTabState();
}

class _DeepSearchTabState extends State<DeepSearchTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  dynamic _selectedCoin;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔍 محرك البحث العميق وفتح الصفقات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amberAccent)),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن أي عملة (مثل: PEPE, BTC, SOL)...',
                    prefixIcon: const Icon(Icons.search, color: Colors.amberAccent),
                    filled: true,
                    fillColor: const Color(0xFF0B0E14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    setState(() {
                      final query = val.trim().toLowerCase();
                      if (query.isNotEmpty && widget.cryptoList.isNotEmpty) {
                        _selectedCoin = widget.cryptoList.firstWhere(
                          (c) => c['symbol'].toString().toLowerCase() == query || c['name'].toString().toLowerCase().contains(query),
                          orElse: () => null,
                        );
                      } else {
                        _selectedCoin = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _selectedCoin == null
              ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('ادخل اسم العملة للبحث المباشر', style: TextStyle(color: Colors.grey))))
              : Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedCoin['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                          Text('السعر: \$${_selectedCoin['current_price']}', style: const TextStyle(color: Colors.amberAccent)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                        icon: const Icon(Icons.flash_on, color: Colors.black),
                        label: const Text('دخول مباشر ⚡', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        onPressed: () => widget.onManualOpen(_selectedCoin),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
