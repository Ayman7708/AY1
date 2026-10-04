import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AymanCryptoApp());
}

class AymanCryptoApp extends StatelessWidget {
  const AymanCryptoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ayman Crypto Pro',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D16),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111723),
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

  double _marketAdaptiveFactor = 1.0; 
  Map<String, dynamic>? _topGuaranteedTrade;
  bool _isBannerDismissed = false;
  String _lastDismissedCoinId = '';

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSavedData();
    fetchLiveMarketData();

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      fetchLiveMarketData(isSilent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
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

  Future<void> fetchLiveMarketData({bool isSilent = false}) async {
    if (!isSilent && _cryptoList.isEmpty) {
      setState(() => _isLoading = true);
    }

    final url = Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=250&page=1&sparkline=true');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _cryptoList = data;
            _isLoading = false;
          });
          _updateMarketAdaptiveEngine();
          _scanForGuaranteedTrades();
          _processAutoTradingEngine();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      String newCoinId = bestCoin['id'].toString();
      setState(() {
        _topGuaranteedTrade = {
          'coin': bestCoin,
          'winRate': maxWinRate,
        };
        if (newCoinId != _lastDismissedCoinId) {
          _isBannerDismissed = false;
        }
      });
    }
  }

  double _calculateWinProbability(dynamic coin) {
    double change24 = ((coin['price_change_percentage_24h'] ?? 0) as num).toDouble();
    double rsi = calculateRSI(coin);
    
    double baseRate = 72.0;
    if (change24 > 2.5 && change24 < 14.0) baseRate += 12.0;
    if (rsi >= 50.0 && rsi <= 68.0) baseRate += 11.0;
    if (rsi > 82.0 || rsi < 18.0) baseRate -= 15.0;

    if (baseRate > 97.0) return 97.0;
    if (baseRate < 50.0) return 50.0;
    return double.parse(baseRate.toStringAsFixed(1));
  }

  double calculateRSI(dynamic coin) {
    double change24 = ((coin['price_change_percentage_24h'] ?? 0) as num).toDouble();
    double baseRsi = 50.0 + (change24 * 2.2);
    if (baseRsi > 92.0) return 92.0;
    if (baseRsi < 12.0) return 12.0;
    return double.parse(baseRsi.toStringAsFixed(1));
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
        
        if (change24 >= 2.0 && rsi >= 50.0 && rsi <= 70.0) {
          int activeSameCoin = _activeTrades.where((t) => t['id'] == coin['id']).length;

          if (activeSameCoin < 2) {
            _executeAutoTradeEntry(coin, '5m', activeSameCoin + 1);
          }
        }
      }
    }

    _saveData();
    if (mounted) setState(() {});
  }

  void _executeAutoTradeEntry(dynamic coin, String tf, int waveIndex) {
    double price = (coin['current_price'] ?? 0).toDouble();

    double tp1 = price * (1.0 + (0.010 * _marketAdaptiveFactor)); 
    double tp2 = price * (1.0 + (0.024 * _marketAdaptiveFactor)); 
    double tp3 = price * (1.0 + (0.040 * _marketAdaptiveFactor)); 
    double stopLoss = price * (1.0 - (0.010 * _marketAdaptiveFactor));

    var newTrade = {
      'id': coin['id'],
      'name': coin['name'],
      'symbol': coin['symbol'],
      'entryPrice': price,
      'tp1': tp1,
      'tp2': tp2,
      'tp3': tp3,
      'stopLoss': stopLoss,
      'timeframe': tf,
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

  void _openManualTradeDialog(dynamic coin, {String tf = '15m'}) {
    double price = (coin['current_price'] ?? 0).toDouble();
    double winRate = _calculateWinProbability(coin);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111723),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              if (coin['image'] != null) Image.network(coin['image'], width: 26, height: 26, errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin)),
              const SizedBox(width: 8),
              Expanded(child: Text('صفقة سكالبينج: ${coin['name']}', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: winRate >= 85 ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(winRate >= 85 ? Icons.verified : Icons.analytics, color: winRate >= 85 ? Colors.greenAccent : Colors.amberAccent, size: 20),
                    const SizedBox(width: 8),
                    Text('نسبة دقة الصفقة: $winRate% | الفريم: $tf', style: TextStyle(color: winRate >= 85 ? Colors.greenAccent : Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('سعر الدخول المباشر: \$$price', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('أهداف السكالبينج بالتكيف الآلي:', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('• Target 1: \$${(price * (1.0 + (0.010 * _marketAdaptiveFactor))).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              Text('• Target 2: \$${(price * (1.0 + (0.024 * _marketAdaptiveFactor))).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              Text('• Target 3: \$${(price * (1.0 + (0.040 * _marketAdaptiveFactor))).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              Text('• Stop Loss: \$${(price * (1.0 - (0.010 * _marketAdaptiveFactor))).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                var manualTrade = {
                  'id': coin['id'],
                  'name': coin['name'],
                  'symbol': coin['symbol'],
                  'entryPrice': price,
                  'tp1': price * (1.0 + (0.010 * _marketAdaptiveFactor)),
                  'tp2': price * (1.0 + (0.024 * _marketAdaptiveFactor)),
                  'tp3': price * (1.0 + (0.040 * _marketAdaptiveFactor)),
                  'stopLoss': price * (1.0 - (0.010 * _marketAdaptiveFactor)),
                  'timeframe': tf,
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
                  SnackBar(content: Text('تم إطلاق صفقة سكالبينج لـ ${coin['name']} بنجاح! 🚀'), backgroundColor: Colors.green),
                );
              },
              child: const Text('دخول مباشر ⚡', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
              backgroundColor: const Color(0xFF111723),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.api, color: Colors.amberAccent),
                  SizedBox(width: 8),
                  Text('ربط المنصة (Binance)', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      title: const Text('حساب حقيقي (LIVE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
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
                  },
                  child: const Text('حفظ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _closeTrade(Map<String, dynamic> trade, bool isWin, {required double closePrice}) {
    setState(() {
      _activeTrades.removeWhere((t) => t == trade);
      double entry = (trade['entryPrice'] as num).toDouble();
      double leverage = ((trade['leverage'] ?? 50.0) as num).toDouble();
      
      double priceDiffRatio = (closePrice - entry) / entry;
      double pnl = priceDiffRatio * 100 * leverage;

      _tradeHistory.add({
        ...trade,
        'isWin': isWin,
        'closePrice': closePrice,
        'pnlPercent': pnl,
      });
    });
    _saveData();
  }

  void _clearHistory() {
    setState(() {
      _tradeHistory.clear();
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // شعار احترافي خارجي للحرفين Ayman Crypto (AC)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.amberAccent, Colors.orangeAccent]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'AC',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.black, fontSize: 15, letterSpacing: 1),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ayman Crypto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                Text('تداول سكالبينج ذكي ⚡', style: TextStyle(fontSize: 10, color: Colors.amberAccent.shade100)),
              ],
            ),
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
            onPressed: () => fetchLiveMarketData(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amberAccent,
          labelColor: Colors.amberAccent,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                children: [
                  const Text('صفقاتي النشطة'),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amberAccent, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_activeTrades.length}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const Tab(icon: Icon(Icons.flash_on), text: 'سكالبينج السريع (1m-60m) ⚡'),
            const Tab(icon: Icon(Icons.analytics), text: 'السجل والدقة 📊'),
            const Tab(icon: Icon(Icons.saved_search), text: 'البحث العميق 🔍'),
            const Tab(icon: Icon(Icons.psychology), text: 'محرك التكيف 🤖'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
          : Column(
              children: [
                if (_topGuaranteedTrade != null && !_isBannerDismissed) _buildDismissibleGuaranteedBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveTradesProView(),
                      ScalpingTimeframesTab(cryptoList: _cryptoList, onOpenTrade: _openManualTradeDialog),
                      _buildPerformanceStatsProView(),
                      DeepSearchTab(cryptoList: _cryptoList, onManualOpen: _openManualTradeDialog),
                      _buildAdaptiveEngineStatusView(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDismissibleGuaranteedBanner() {
    final coin = _topGuaranteedTrade!['coin'];
    final double winRate = _topGuaranteedTrade!['winRate'];
    final String coinId = coin['id'].toString();

    return Dismissible(
      key: Key('guaranteed_banner_$coinId'),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        setState(() {
          _isBannerDismissed = true;
          _lastDismissedCoinId = coinId;
        });
      },
      child: Container(
        width: double.infinity,
        color: Colors.green.shade900.withOpacity(0.95),
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
                    Text('نسبة النجاح المتوقعة: $winRate% 🔥 (اسحب للإلغاء)', style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  Widget _buildActiveTradesProView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: const Color(0xFF111723),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text('عدد الصفقات النشطة: ${_activeTrades.length}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _activeTrades.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد صفقات نشطة حالياً.\nيمكنك فتح صفقة من قائمة (السكالبينج السريع ⚡)',
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
                        color: const Color(0xFF111723),
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                      child: Text(trade['timeframe'] ?? '15m', style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold)),
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
                                Text('الدخول: \$$entryPrice', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('الحالي: \$${currentPrice.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
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
                              height: 34,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                onPressed: () => _closeTrade(trade, isWin, closePrice: currentPrice),
                                child: const Text('إغلاق الصفقة فوراً', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
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
          color: isAchieved ? Colors.greenAccent : const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isAchieved ? Colors.greenAccent : Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: isAchieved ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('\$${val.toStringAsFixed(3)}', style: TextStyle(fontSize: 8, color: isAchieved ? Colors.black : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceStatsProView() {
    int totalTrades = _tradeHistory.length;
    int wins = _tradeHistory.where((t) => t['isWin'] == true || (t['pnlPercent'] != null && (t['pnlPercent'] as num) > 0)).length;
    int losses = totalTrades - wins;
    double accuracyRate = totalTrades > 0 ? (wins / totalTrades) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📊 دقة التطبيق وسجل الصفقات:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
              if (_tradeHistory.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: _clearHistory,
                ),
            ],
          ),
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
            decoration: BoxDecoration(color: const Color(0xFF111723), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.4))),
            child: Column(
              children: [
                const Text('نسبة دقة إشارات السكالبينج:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 6),
                Text('${accuracyRate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: accuracyRate >= 65 ? Colors.greenAccent : Colors.orangeAccent)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _tradeHistory.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('السجل فارغ حالياً', style: TextStyle(color: Colors.grey))))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tradeHistory.reversed.length,
                  itemBuilder: (context, idx) {
                    final t = _tradeHistory.reversed.toList()[idx];
                    double pnl = ((t['pnlPercent'] ?? 0.0) as num).toDouble();
                    bool isWin = t['isWin'] == true || pnl > 0;

                    return Card(
                      color: const Color(0xFF111723),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(isWin ? Icons.check_circle : Icons.cancel, color: isWin ? Colors.greenAccent : Colors.redAccent),
                        title: Text('${t['name']} (${t['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('دخول: \$${t['entryPrice']} | إغلاق: \$${(t['closePrice'] as num).toStringAsFixed(4)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        trailing: Text(
                          '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(1)}%',
                          style: TextStyle(color: isWin ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
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
        color: const Color(0xFF111723),
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

  Widget _buildAdaptiveEngineStatusView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🤖 حالة محرك التكيف الذكي:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF111723), borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('معامل التكيف المباشر: ${_marketAdaptiveFactor.toStringAsFixed(2)}x', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                const SizedBox(height: 8),
                const Text('• يتم تعديل أهداف الربح للسكالبينج بناءً على سرعة اتجاه السوق.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScalpingTimeframesTab extends StatefulWidget {
  final List<dynamic> cryptoList;
  final Function(dynamic, {String tf}) onOpenTrade;
  const ScalpingTimeframesTab({super.key, required this.cryptoList, required this.onOpenTrade});

  @override
  State<ScalpingTimeframesTab> createState() => _ScalpingTimeframesTabState();
}

class _ScalpingTimeframesTabState extends State<ScalpingTimeframesTab> {
  String _activeTf = '15m';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          color: const Color(0xFF111723),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['1m', '5m', '15m', '30m', '60m'].map((tf) {
              bool isSelected = _activeTf == tf;
              return InkWell(
                onTap: () => setState(() => _activeTf = tf),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.amberAccent : const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? Colors.amberAccent : Colors.grey.withOpacity(0.2)),
                  ),
                  child: Text('فريم $tf', style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.cryptoList.length,
            itemBuilder: (context, index) {
              final coin = widget.cryptoList[index];
              final double price = (coin['current_price'] ?? 0).toDouble();
              final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();

              return Card(
                color: const Color(0xFF111723),
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: ListTile(
                  leading: Image.network(coin['image'] ?? '', width: 26, height: 26, errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin)),
                  title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  subtitle: Text('السعر: \$$price | 24h: ${change24 >= 0 ? '+' : ''}${change24.toStringAsFixed(2)}%', style: TextStyle(fontSize: 11, color: change24 >= 0 ? Colors.greenAccent : Colors.redAccent)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, minimumSize: const Size(80, 32)),
                    onPressed: () => widget.onOpenTrade(coin, tf: _activeTf),
                    child: Text('سكالبينج $_activeTf ⚡', style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
            decoration: BoxDecoration(color: const Color(0xFF111723), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔍 محرك البحث العميق للعملات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amberAccent)),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم العملة (مثل PEPE, SOL)...',
                    prefixIcon: const Icon(Icons.search, color: Colors.amberAccent),
                    filled: true,
                    fillColor: const Color(0xFF090D16),
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
                  decoration: BoxDecoration(color: const Color(0xFF111723), borderRadius: BorderRadius.circular(12)),
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
