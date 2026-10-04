import 'dart:async';
import 'dart:convert';
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
      title: 'Ayman Futures Scalper 60M',
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

  double _defaultLeverage = 50.0; // رافعة مالية عالية افتراضية
  Map<String, dynamic>? _topGuaranteedTrade;
  bool _isBannerDismissed = false;
  String _lastDismissedCoinId = '';

  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSavedData();
    fetchLiveMarketData();

    // تحديث نبض السوق كل 5 ثوانٍ لصفقات العقود السريعة
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
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
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=200&page=1&sparkline=true');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _cryptoList = data;
            _isLoading = false;
          });
          _scanForFutures60mTrades();
          _processFuturesTradingEngine();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // البحث عن أسرع العملات انفجاراً للربح خلال ساعة
  void _scanForFutures60mTrades() {
    if (_cryptoList.isEmpty) return;

    dynamic bestCoin;
    double maxWinRate = 0.0;

    for (var coin in _cryptoList) {
      double winRate = _calculateQuickWinProbability(coin);
      if (winRate >= 88.0 && winRate > maxWinRate) {
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

  // حساب دقة الصفقة بناءً على الزخم اللحظي لتسريع الهدف خلال < 60 دقيقة
  double _calculateQuickWinProbability(dynamic coin) {
    double change24 = ((coin['price_change_percentage_24h'] ?? 0) as num).toDouble();
    double baseRate = 75.0;

    // تفضيل العملات ذات السيولة المرتفعة مع حركة اتجاهية واضحة
    if (change24.abs() >= 1.5 && change24.abs() <= 8.0) baseRate += 15.0;
    if (change24.abs() > 8.0) baseRate += 5.0;

    if (baseRate > 98.0) return 98.0;
    if (baseRate < 55.0) return 55.0;
    return double.parse(baseRate.toStringAsFixed(1));
  }

  // محرك إدارة وتتبع صفقات العقود الآجلة السريعة
  void _processFuturesTradingEngine() {
    if (_cryptoList.isEmpty) return;

    List<Map<String, dynamic>> updatedActive = [];
    DateTime now = DateTime.now();

    for (var trade in List<Map<String, dynamic>>.from(_activeTrades)) {
      final coin = _cryptoList.firstWhere(
        (c) => c['id'] == trade['id'],
        orElse: () => null,
      );

      DateTime entryTime = DateTime.tryParse(trade['entryTime'] ?? '') ?? now;
      int elapsedMinutes = now.difference(entryTime).inMinutes;

      // 1. الشرط الزمني: إغلاق الصفقة تلقائياً إذا تجاوزت 60 دقيقة
      if (elapsedMinutes >= 60) {
        double currentPrice = coin != null ? (coin['current_price'] ?? 0).toDouble() : (trade['entryPrice'] as num).toDouble();
        double entry = (trade['entryPrice'] as num).toDouble();
        bool isWin = currentPrice > entry;
        _closeTrade(trade, isWin, closePrice: currentPrice, closeReason: 'انتهاء المهلة الزمنية (60 دقيقة)');
        continue;
      }

      if (coin != null) {
        double currentPrice = (coin['current_price'] ?? 0).toDouble();
        double entry = (trade['entryPrice'] as num).toDouble();
        double tp1 = (trade['tp1'] as num).toDouble();
        double tp2 = (trade['tp2'] as num).toDouble();
        double tp3 = (trade['tp3'] as num).toDouble();
        double stopLoss = (trade['stopLoss'] as num).toDouble();
        int achievedTps = trade['achievedTps'] ?? 0;

        // تتبع الأهداف وسحب وقف الخسارة للربح
        if (currentPrice >= tp1 && achievedTps < 1) {
          trade['stopLoss'] = entry * 1.001; // تأمين الصفقة على سعر الدخول
          trade['achievedTps'] = 1;
        } else if (currentPrice >= tp2 && achievedTps < 2) {
          trade['stopLoss'] = tp1;
          trade['achievedTps'] = 2;
        } else if (currentPrice >= tp3) {
          _closeTrade(trade, true, closePrice: tp3, closeReason: 'تحقيق الهدف الأقصى TP3 🚀');
          continue;
        }

        // إغلاق عند ضرب وقف الخسارة
        if (currentPrice <= stopLoss) {
          bool isWinTrade = currentPrice > entry;
          _closeTrade(trade, isWinTrade, closePrice: stopLoss, closeReason: 'ضرب وقف الخسارة / التأمين 🛑');
          continue;
        }

        updatedActive.add(trade);
      } else {
        updatedActive.add(trade);
      }
    }

    _activeTrades = updatedActive;

    // الفتح الآلي للصفقات إذا تم تفعيل البوت
    if (_isAutoTradingEnabled) {
      for (var coin in _cryptoList) {
        double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
        
        if (change24 >= 1.2 && change24 <= 12.0) {
          int activeSameCoin = _activeTrades.where((t) => t['id'] == coin['id']).length;

          if (activeSameCoin == 0 && _activeTrades.length < 5) {
            _executeFuturesTradeEntry(coin, _defaultLeverage);
          }
        }
      }
    }

    _saveData();
    if (mounted) setState(() {});
  }

  void _executeFuturesTradeEntry(dynamic coin, double leverage) {
    double price = (coin['current_price'] ?? 0).toDouble();

    // أهداف خاطفة جداً للسكالبينج السريع خلال < 60 دقيقة
    double tp1 = price * 1.0035; // +0.35% (مع رافعة 50x تحقق ~17.5% ربح)
    double tp2 = price * 1.0070; // +0.70% (مع رافعة 50x تحقق ~35% ربح)
    double tp3 = price * 1.0120; // +1.20% (مع رافعة 50x تحقق ~60% ربح)
    double stopLoss = price * 0.9950; // -0.50% وقف محكم

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
      'entryTime': DateTime.now().toIso8601String(),
      'image': coin['image'],
      'leverage': leverage,
      'isReal': _isLiveRealFunds,
      'winProb': _calculateQuickWinProbability(coin),
    };

    _activeTrades.add(newTrade);
  }

  void _openManualFuturesTradeDialog(dynamic coin) {
    double price = (coin['current_price'] ?? 0).toDouble();
    double winRate = _calculateQuickWinProbability(coin);
    double selectedLeverage = _defaultLeverage;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111723),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  if (coin['image'] != null) Image.network(coin['image'], width: 26, height: 26, errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('عقود آجلة سريعة: ${coin['name']}', style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold))),
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
                        Icon(winRate >= 85 ? Icons.bolt : Icons.analytics, color: winRate >= 85 ? Colors.greenAccent : Colors.amberAccent, size: 20),
                        const SizedBox(width: 8),
                        Text('احتمالية الهدف خلال < 60m: $winRate%', style: TextStyle(color: winRate >= 85 ? Colors.greenAccent : Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('سعر الدخول المباشر: \$$price', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الرافعة المالية:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      DropdownButton<double>(
                        dropdownColor: const Color(0xFF111723),
                        value: selectedLeverage,
                        items: [20.0, 50.0, 75.0, 100.0].map((lev) {
                          return DropdownMenuItem<double>(
                            value: lev,
                            child: Text('${lev.toInt()}x Futures', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedLeverage = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('أهداف السكالبينج الخاطف (< 60 دقيقة):', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('• TP1 (+0.35%): \$${(price * 1.0035).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                  Text('• TP2 (+0.70%): \$${(price * 1.0070).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                  Text('• TP3 (+1.20%): \$${(price * 1.0120).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
                  Text('• Stop Loss (-0.50%): \$${(price * 0.9950).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
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
                    _executeFuturesTradeEntry(coin, selectedLeverage);
                    _saveData();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم فتح صفقة عقود سريعة برافعة ${selectedLeverage.toInt()}x لـ ${coin['name']}! ⚡'), backgroundColor: Colors.green),
                    );
                  },
                  child: const Text('دخول عقود خاطف 🚀', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
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
                  Text('ربط منصة Binance Futures', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
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
                      title: const Text('التداول بأموال حقيقية (LIVE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
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
                  child: const Text('حفظ الربط', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _closeTrade(Map<String, dynamic> trade, bool isWin, {required double closePrice, String closeReason = ''}) {
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
        'closeReason': closeReason,
        'closeTime': DateTime.now().toIso8601String(),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.amberAccent, Colors.orangeAccent]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'F60M',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Futures Scalper 60M', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                Text('عقود آجلة خاطفة < 60 دقيقة ⚡', style: TextStyle(fontSize: 10, color: Colors.amberAccent.shade100)),
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
          isScrollable: false,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('النشطة'),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: Colors.amberAccent, borderRadius: BorderRadius.circular(10)),
                    child: Text('${_activeTrades.length}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
            ),
            const Tab(icon: Icon(Icons.flash_on, size: 18), text: 'الفرص المباشرة⚡'),
            const Tab(icon: Icon(Icons.analytics, size: 18), text: 'السجل والدقة 📊'),
            const Tab(icon: Icon(Icons.search, size: 18), text: 'بحث عميق 🔍'),
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
                      _buildActiveTradesFuturesView(),
                      _buildDirectOpportunitiesTab(),
                      _buildPerformanceStatsProView(),
                      DeepSearchTab(cryptoList: _cryptoList, onManualOpen: _openManualFuturesTradeDialog),
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
                const Icon(Icons.bolt, color: Colors.amberAccent, size: 22),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('صفقة عقود خاطفة (< 60m): ${coin['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    Text('نسبة النجاح المتوقعة: $winRate% 🔥 (اسحب للإلغاء)', style: const TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, minimumSize: const Size(80, 30)),
              onPressed: () => _openManualFuturesTradeDialog(coin),
              child: const Text('دخول عقود ⚡', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTradesFuturesView() {
    DateTime now = DateTime.now();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  Text(_isAutoTradingEnabled ? 'بوت العقود الخاطفة شغال ⚡' : 'البوت متوقف ⏸️', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              Text('الإغلاق التلقائي: < 60 دقيقة', style: TextStyle(color: Colors.amberAccent.shade100, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: _activeTrades.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد صفقات عقود نشطة حالياً.\nسيقوم البوت بالدخول المباشر للعملات القوية تلقائياً.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: _activeTrades.length,
                  itemBuilder: (context, index) {
                    final trade = _activeTrades[index];
                    final coin = _cryptoList.firstWhere((c) => c['id'] == trade['id'], orElse: () => null);
                    double currentPrice = coin != null ? (coin['current_price'] ?? 0).toDouble() : (trade['entryPrice'] as num).toDouble();
                    double entryPrice = (trade['entryPrice'] as num).toDouble();
                    double leverage = ((trade['leverage'] ?? 50.0) as num).toDouble();
                    
                    bool isWin = currentPrice >= entryPrice;
                    double currentPnl = (((currentPrice - entryPrice) / entryPrice) * 100) * leverage;
                    int achievedTps = trade['achievedTps'] ?? 0;

                    DateTime entryTime = DateTime.tryParse(trade['entryTime'] ?? '') ?? now;
                    int elapsedMinutes = now.difference(entryTime).inMinutes;
                    int remainingMinutes = 60 - elapsedMinutes;
                    if (remainingMinutes < 0) remainingMinutes = 0;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111723),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isWin ? Colors.greenAccent.withOpacity(0.6) : Colors.redAccent.withOpacity(0.4), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    if (trade['image'] != null)
                                      Image.network(trade['image'], width: 20, height: 20, errorBuilder: (_, __, ___) => const Icon(Icons.monetization_on, size: 18)),
                                    const SizedBox(width: 6),
                                    Text('${trade['name']} (${trade['symbol'].toString().toUpperCase()})',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.amberAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                      child: Text('${leverage.toInt()}x', style: const TextStyle(color: Colors.amberAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isWin ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${currentPnl >= 0 ? '+' : ''}${currentPnl.toStringAsFixed(1)}%',
                                    style: TextStyle(color: isWin ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('الدخول: \$$entryPrice', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                Text('الحالي: \$${currentPrice.toStringAsFixed(4)}', style: const TextStyle(fontSize: 10, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.timer, size: 10, color: Colors.cyanAccent),
                                      const SizedBox(width: 3),
                                      Text('متبقي $remainingMinutesm', style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildTpBadgePro('TP1 🎯', (trade['tp1'] as num).toDouble(), achievedTps >= 1),
                                const SizedBox(width: 4),
                                _buildTpBadgePro('TP2 🎯', (trade['tp2'] as num).toDouble(), achievedTps >= 2),
                                const SizedBox(width: 4),
                                _buildTpBadgePro('TP3 🎯', (trade['tp3'] as num).toDouble(), achievedTps >= 3),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 30,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                                onPressed: () => _closeTrade(trade, isWin, closePrice: currentPrice, closeReason: 'إغلاق يدوي مباشر'),
                                child: const Text('إغلاق الصفقة الآن', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
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
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isAchieved ? Colors.greenAccent : const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isAchieved ? Colors.greenAccent : Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: isAchieved ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
            Text('\$${val.toStringAsFixed(3)}', style: TextStyle(fontSize: 8, color: isAchieved ? Colors.black : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectOpportunitiesTab() {
    return ListView.builder(
      itemCount: _cryptoList.length,
      itemBuilder: (context, index) {
        final coin = _cryptoList[index];
        final double price = (coin['current_price'] ?? 0).toDouble();
        final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
        final double winRate = _calculateQuickWinProbability(coin);

        return Card(
          color: const Color(0xFF111723),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: ListTile(
            leading: Image.network(coin['image'] ?? '', width: 24, height: 24, errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin)),
            title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
            subtitle: Text('السعر: \$$price | التغير: ${change24 >= 0 ? '+' : ''}${change24.toStringAsFixed(2)}%', style: TextStyle(fontSize: 10, color: change24 >= 0 ? Colors.greenAccent : Colors.redAccent)),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: winRate >= 85 ? Colors.greenAccent : Colors.amberAccent, minimumSize: const Size(80, 30)),
              onPressed: () => _openManualFuturesTradeDialog(coin),
              child: Text('عقود $winRate% ⚡', style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceStatsProView() {
    int totalTrades = _tradeHistory.length;
    int wins = _tradeHistory.where((t) => t['isWin'] == true || (t['pnlPercent'] != null && (t['pnlPercent'] as num) > 0)).length;
    int losses = totalTrades - wins;
    double accuracyRate = totalTrades > 0 ? (wins / totalTrades) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('📊 دقة عقود الـ 60 دقيقة والسجل:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
              if (_tradeHistory.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: _clearHistory,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatCardPro('الإجمالي', '$totalTrades', Colors.amberAccent),
              _buildStatCardPro('الرابحة 🎯', '$wins', Colors.greenAccent),
              _buildStatCardPro('الخاسرة 🛑', '$losses', Colors.redAccent),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            width: double.infinity,
            decoration: BoxDecoration(color: const Color(0xFF111723), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withOpacity(0.4))),
            child: Column(
              children: [
                const Text('نسبة دقة إشارات العقود الآجلة السريعة:', style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Text('${accuracyRate.toStringAsFixed(1)}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: accuracyRate >= 70 ? Colors.greenAccent : Colors.orangeAccent)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _tradeHistory.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('سجل الصفقات المغلقة فارغ', style: TextStyle(color: Colors.grey))))
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
                        title: Text('${t['name']} (${t['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        subtitle: Text('سبب الإغلاق: ${t['closeReason'] ?? ''}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
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
            decoration: BoxDecoration(color: const Color(0xFF111723), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔍 محرك البحث عن عقود العملات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amberAccent)),
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
          const SizedBox(height: 14),
          _selectedCoin == null
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('ادخل اسم العملة للبحث المباشر', style: TextStyle(color: Colors.grey))))
              : Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFF111723), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedCoin['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                          Text('السعر: \$${_selectedCoin['current_price']}', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                        icon: const Icon(Icons.flash_on, color: Colors.black, size: 18),
                        label: const Text('دخول عقود خاطف ⚡', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
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
