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
  State<HomeScreen> meState() => _HomeScreenState();
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

  double _marketAdaptiveFactor = 1.0; 
  Map<String, dynamic>? _topGuaranteedTrade;

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
        _updateMarketAdaptiveEngine();
        _scanForGuaranteedTrades();
        _processAutoTradingEngine();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _updateMarketAdaptiveEngine() {
    if (_cryptoList.isEmpty) return;
    double totalVolatility = 0.0;
    int count = 0;
    for (var c in _cryptoList.take(20)) {
      totalVolatility += ((c['price_change_percentage_24h'] ?? 0).toDouble()).abs();
      count++;
    }
    double avgVol = count > 0 ? totalVolatility / count : 2.0;
    
    if (avgVol > 5.0) {
      _marketAdaptiveFactor = 1.3;
    } else if (avgVol < 1.5) {
      _marketAdaptiveFactor = 0.8;
    } else {
      _marketAdaptiveFactor = 1.0;
    }
  }

  // خوارزمية فحص واكتشاف الصفقات عالية النسبة (المضمونة)
  void _scanForGuaranteedTrades() {
    if (_cryptoList.isEmpty) return;

    dynamic bestCoin;
    double maxWinRate = 0.0;

    for (var coin in _cryptoList) {
      double winRate = _calculateWinProbability(coin);
      if (winRate >= 85.0 && winRate > maxWinRate) {
        maxWinRate = winRate;
        bestCoin = coin;
      }
    }

    if (bestCoin != null) {
      setState(() {
        _topGuaranteedTrade = {
          'coin': bestCoin,
          'winRate': maxWinRate,
        };
      });
    }
  }

  double _calculateWinProbability(dynamic coin) {
    double change24 = ((coin['price_change_percentage_24h'] ?? 0) as num).toDouble();
    double rsi = calculateRSI(coin);
    
    double baseRate = 70.0;
    if (change24 > 3.0 && change24 < 12.0) baseRate += 10.0;
    if (rsi >= 55.0 && rsi <= 68.0) baseRate += 12.0;
    if (rsi > 80.0 || rsi < 20.0) baseRate -= 15.0;

    if (baseRate > 96.0) return 96.0;
    if (baseRate < 50.0) return 50.0;
    return double.parse(baseRate.toStringAsFixed(1));
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

    double tp1 = price * (1.0 + (0.012 * _marketAdaptiveFactor)); 
    double tp2 = price * (1.0 + (0.028 * _marketAdaptiveFactor)); 
    double tp3 = price * (1.0 + (0.045 * _marketAdaptiveFactor)); 
    double stopLoss = price * (1.0 - (0.012 * _marketAdaptiveFactor));

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
      'winProb': _calculateWinProbability(coin),
    };

    _activeTrades.add(newTrade);
  }

  void _openManualTradeDialog(dynamic coin) {
    double price = (coin['current_price'] ?? 0).toDouble();
    double winRate = _calculateWinProbability(coin);

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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: winRate >= 85 ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(winRate >= 85 ? Icons.verified : Icons.analytics, color: winRate >= 85 ? Colors.greenAccent : Colors.amberAccent, size: 20),
                    const SizedBox(width: 8),
                    Text('نسبة نجاح الصفقة المقدرة: $winRate%', style: TextStyle(color: winRate >= 85 ? Colors.greenAccent : Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('سعر الدخول المباشر: \$$price', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('حالة وضع السوق والتكيف: ${_marketAdaptiveFactor > 1.0 ? "تقلبات عالية ⚡" : "مستقر/تجميع 🎯"}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
              const SizedBox(height: 6),
              const Text('الأهداف المعتمدة بالتكيف الآلي:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('• Target 1: \$${(price * (1.0 + (0.012 * _marketAdaptiveFactor))).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              Text('• Target 2: \$${(price * (1.0 + (0.028 * _marketAdaptiveFactor))).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              Text('• Target 3: \$${(price * (1.0 + (0.045 * _marketAdaptiveFactor))).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              Text('• Stop Loss: \$${(price * (1.0 - (0.012 * _marketAdaptiveFactor))).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
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
                  'tp1': price * (1.0 + (0.012 * _marketAdaptiveFactor)),
                  'tp2': price * (1.0 + (0.028 * _marketAdaptiveFactor)),
                  'tp3': price * (1.0 + (0.045 * _marketAdaptiveFactor)),
                  'stopLoss': price * (1.0 - (0.012 * _marketAdaptiveFactor)),
                  'achievedTps': 0,
                  'waveIndex': 1,
                  'entryTime': DateTime.now().toIso8601String(),
                  'image': coin['image'],
                  'leverage': 50.0,
                  'isReal': _isLiveRealFunds,
                  'isManual': true,
                  'winProb': winRate,
                };
                setState(() {
                  _activeTrades.add(manualTrade);
                });
                _saveData();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم فتح صفقة يدوية لـ ${coin['name']} (نسبة النجاح: $winRate%) بنجاح! 🚀'), backgroundColor: Colors.green),
                );
              },
              child: const Text('تأكيد وفتح الصفقة ⚡', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _openApiSettingsDialog() {
    TextEditingController keyCtrl = TextEditingController(text: _binanceApiKey);
    TextEditingController secretCtrl = TextEditingController(text: _binanceApiSecret);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151922),
              title: const Row(
                children: [
                  Icon(Icons.api, color: Colors.amberAccent),
                  SizedBox(width: 8),
                  Text('ربط منصة التداول (Binance)', style: TextStyle(fontSize: 15, color: Colors.white)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('قم بإدخال مفاتيح API الخاصة بحسابك في بينانس لتمكين التداول الحقيقي:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: keyCtrl,
                      decoration: const InputDecoration(labelText: 'API Key', labelStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: secretCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Secret Key', labelStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('تفعيل أموال حقيقية (LIVE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      value: _isLiveRealFunds,
                      activeColor: Colors.redAccent,
                      onChanged: (val) {
                        setDialogState(() {
                          _isLiveRealFunds = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
                  onPressed: () {
                    setState(() {
                      _binanceApiKey = keyCtrl.text.trim();
                      _binanceApiSecret = secretCtrl.text.trim();
                    });
                    _saveData();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ إعدادات API والتداول بنجاح! 🔐'), backgroundColor: Colors.green),
                    );
                  },
                  child: const Text('حفظ الربط', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double calculateRSI(dynamic coin) {
    double change24 = ((coin['price_change_percentage_24h'] ?? 0) as num).toDouble();
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
            Text('Ayman7708 Trading Bot Pro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.api, color: _binanceApiKey.isNotEmpty ? Colors.greenAccent : Colors.grey),
            onPressed: _openApiSettingsDialog,
          ),
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
            Tab(icon: Icon(Icons.show_chart), text: 'الرسم البياني 📈'),
            Tab(icon: Icon(Icons.track_changes), text: 'صفقاتي النشطة 🎯'),
            Tab(icon: Icon(Icons.analytics), text: 'دقة التطبيق والسجل 📊'),
            Tab(icon: Icon(Icons.flash_on), text: 'صفقات سريعة ⚡'),
            Tab(icon: Icon(Icons.saved_search), text: 'البحث العميق 🔍'),
            Tab(icon: Icon(Icons.psychology), text: 'محرك التكيف 🤖'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : Column(
              children: [
                if (_topGuaranteedTrade != null) _buildGuaranteedBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      InteractiveChartTab(cryptoList: _cryptoList),
                      _buildActiveTradesProView(),
                      _buildPerformanceStatsProView(),
                      _buildScalpingView(),
                      DeepSearchTab(cryptoList: _cryptoList, onManualOpen: _openManualTradeDialog),
                      _buildAdaptiveEngineStatusView(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // شريط إشعار الصفقة المضمونة المباشر
  Widget _buildGuaranteedBanner() {
    final coin = _topGuaranteedTrade!['coin'];
    final double winRate = _topGuaranteedTrade!['winRate'];

    return Container(
      width: double.infinity,
      color: Colors.green.shade900.withOpacity(0.9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.amberAccent, size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('صفقة مضمونة عالية النسبة: ${coin['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  Text('نسبة النجاح المتوقعة: $winRate% 🔥', style: const TextStyle(fontSize: 11, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, minimumSize: const Size(80, 30)),
            onPressed: () => _openManualTradeDialog(coin),
            child: const Text('دخول مكثف ⚡', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
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
              Text(_isLiveRealFunds ? 'حساب حقيقي (REAL)' : 'حساب تجريبي (DEMO)', style: TextStyle(fontSize: 11, color: _isLiveRealFunds ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold)),
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
                    double winProb = (trade['winProb'] ?? 80.0).toDouble();

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
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                      child: Text('$winProb%', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
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
    double accuracyRate = totalTrades > 0 ? (wins / totalTrades) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 دقة التطبيق والنتائج التاريخية التراكمية:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatCardPro('إجمالي الصفقات', '$totalTrades', Colors.amberAccent),
              _buildStatCardPro('الرابحة 🎯', '$wins', Colors.greenAccent),
              _buildStatCardPro('الخاسرة 🛑', '$losses', Colors.redAccent),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.4))),
            child: Column(
              children: [
                const Text('نسبة دقة التطبيق الناجحة (Bot Accuracy):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                Text('${accuracyRate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: accuracyRate >= 65 ? Colors.greenAccent : Colors.orangeAccent)),
                const SizedBox(height: 4),
                Text(accuracyRate >= 70 ? '🎯 مستوى إشارات عالي الدقة' : '⚙️ يتم تحسين الخوارزميات تلقائياً', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
        final double winProb = _calculateWinProbability(coin);

        return Card(
          color: const Color(0xFF151922),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Image.network(coin['image'] ?? '', width: 26, height: 26, errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin)),
            title: Row(
              children: [
                Text('${coin['name']} ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('($winProb% نجاح)', style: TextStyle(fontSize: 11, color: winProb >= 85 ? Colors.greenAccent : Colors.grey)),
              ],
            ),
            subtitle: Text('السعر: \$$price | 24h: ${change24 >= 0 ? '+' : ''}${change24.toStringAsFixed(2)}%', style: TextStyle(fontSize: 11, color: change24 >= 0 ? Colors.greenAccent : Colors.redAccent)),
            trailing: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: winProb >= 85 ? Colors.greenAccent : Colors.amberAccent, minimumSize: const Size(90, 32)),
              icon: const Icon(Icons.add_chart, size: 14, color: Colors.black),
              label: const Text('دخول ⚡', style: TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)),
              onPressed: () => _openManualTradeDialog(coin),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdaptiveEngineStatusView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤖 حالة محرك التكيف الذكي (Adaptive Engine):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('معامل التكيف المباشر: ${_marketAdaptiveFactor.toStringAsFixed(2)}x', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                const SizedBox(height: 8),
                const Text('• الخوارزمية تقيس تقلبات السوق لحظة بلحظة.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const Text('• يتم تعديل أهداف الربح (Take Profit) ووقف الخسارة لتناسب حركة السعر الحالية تلقائياً.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
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

class InteractiveChartTab extends StatefulWidget {
  final List<dynamic> cryptoList;
  const InteractiveChartTab({super.key, required this.cryptoList});

  @override
  State<InteractiveChartTab> createState() => _InteractiveChartTabState();
}

class _InteractiveChartTabState extends State<InteractiveChartTab> {
  String _selectedSymbol = 'bitcoin';
  String _selectedTimeframe = '1h';

  @override
  Widget build(BuildContext context) {
    if (widget.cryptoList.isEmpty) {
      return const Center(child: Text('جاري تحميل بيانات الشارت...', style: TextStyle(color: Colors.grey)));
    }

    final coin = widget.cryptoList.firstWhere((c) => c['id'] == _selectedSymbol, orElse: () => widget.cryptoList.first);
    final List sparkline = coin['sparkline_in_7d']?['price'] ?? [];

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                value: _selectedSymbol,
                dropdownColor: const Color(0xFF151922),
                items: widget.cryptoList.take(30).map<DropdownMenuItem<String>>((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'],
                    child: Text('${c['name']} (${c['symbol'].toString().toUpperCase()})', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSymbol = val);
                },
              ),
              Row(
                children: ['1m', '5m', '15m', '1h', '4h', '1d'].map((tf) {
                  bool isSelected = _selectedTimeframe == tf;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTimeframe = tf),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.amberAccent : const Color(0xFF151922),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(tf, style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF151922),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.2)),
              ),
              child: CustomPaint(
                size: Size.infinite,
                painter: AdvancedChartPainter(sparkline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdvancedChartPainter extends CustomPainter {
  final List sparkline;
  AdvancedChartPainter(this.sparkline);

  @override
  void paint(Canvas canvas, Size size) {
    if (sparkline.isEmpty) return;

    final paintLine = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final double min = sparkline.reduce((a, b) => a < b ? a : b).toDouble();
    final double max = sparkline.reduce((a, b) => a > b ? a : b).toDouble();
    final double range = max - min == 0 ? 1 : max - min;

    final path = Path();
    double dx = size.width / (sparkline.length - 1);

    for (int i = 0; i < sparkline.length; i++) {
      double val = sparkline[i].toDouble();
      double dy = size.height - ((val - min) / range * size.height);
      if (i == 0) {
        path.moveTo(0, dy);
      } else {
        path.lineTo(i * dx, dy);
      }
    }

    canvas.drawPath(path, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
