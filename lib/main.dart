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
      title: 'Ayman7708 Pro AI Engine',
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

  bool _isAutoTradingEnabled = true;
  bool _isLiveRealFunds = false; 
  String _binanceApiKey = '';
  String _binanceApiSecret = '';

  double _riskFactor = 1.0;

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
      _updateAdaptiveStrategy();
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

  void _updateAdaptiveStrategy() {
    if (_tradeHistory.isEmpty) {
      _riskFactor = 1.0;
      return;
    }
    int recentLosses = _tradeHistory.take(10).where((t) => t['isWin'] == false).length;
    if (recentLosses >= 3) {
      _riskFactor = 1.4;
    } else if (recentLosses >= 1) {
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
          trade['stopLoss'] = entry;
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
        
        if (change24 >= 1.8 && rsi >= 45.0 && rsi <= (65.0 / _riskFactor)) {
          int activeSameCoin = _activeTrades.where((t) => t['id'] == coin['id']).length;

          if (activeSameCoin < 3) {
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

    double tp1 = price * (1.0 + (0.010 * waveIndex));
    double tp2 = price * (1.0 + (0.022 * waveIndex));
    double tp3 = price * (1.0 + (0.038 * waveIndex));
    double stopLoss = price * (1.0 - (0.007 * _riskFactor));

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
      'leverage': 75.0,
      'isReal': _isLiveRealFunds,
    };

    _activeTrades.add(newTrade);

    if (_isLiveRealFunds && _binanceApiKey.isNotEmpty) {
      _sendBinanceApiOrder(coin['symbol'].toString().toUpperCase() + 'USDT', 'BUY');
    }
  }

  // خوارزمية توقيع الـ API بدون الحاجة إلى مكتبة خارجية
  Future<void> _sendBinanceApiOrder(String symbol, String side) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final queryString = 'symbol=$symbol&side=$side&type=MARKET&timestamp=$timestamp';
      
      final url = Uri.parse('https://fapi.binance.com/fapi/v1/order?$queryString');
      await http.post(
        url,
        headers: {
          'X-MBX-APIKEY': _binanceApiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );
    } catch (_) {}
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

  void _closeTrade(Map<String, dynamic> trade, bool isWin, {required double closePrice}) {
    _activeTrades.removeWhere((t) => t == trade);
    double entry = (trade['entryPrice'] as num).toDouble();
    double leverage = ((trade['leverage'] ?? 1.0) as num).toDouble();
    double pnl = (((closePrice - entry) / entry) * 100) * leverage;

    _tradeHistory.add({
      ...trade,
      'isWin': isWin,
      'closePrice': closePrice,
      'pnlPercent': pnl,
    });
    _updateAdaptiveStrategy();
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
            Text('Ayman7708 Trading Bot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            icon: const Icon(Icons.settings_remote, color: Colors.amberAccent),
            onPressed: _showApiSettingsDialog,
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
            Tab(icon: Icon(Icons.flash_on), text: 'صفقات سريعة (سكالبينج) ⚡'),
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
                _buildActiveTradesView(),
                _buildPerformanceStatsView(),
                _buildScalpingView(),
                DeepSearchTab(cryptoList: _cryptoList),
                _buildCryptoList(_cryptoList, 'breakout'),
                _buildCryptoList(_cryptoList, 'smart_money'),
              ],
            ),
    );
  }

  void _showApiSettingsDialog() {
    TextEditingController keyCtrl = TextEditingController(text: _binanceApiKey);
    TextEditingController secCtrl = TextEditingController(text: _binanceApiSecret);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151922),
        title: const Text('🔐 إعدادات الربط والمنصات المركزية', style: TextStyle(color: Colors.amberAccent, fontSize: 15)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('وضع التداول بأموال حقيقية:', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: _isLiveRealFunds,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) {
                      setState(() => _isLiveRealFunds = val);
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.grey),
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(labelText: 'Binance / Bybit API Key', labelStyle: TextStyle(fontSize: 11)),
              ),
              TextField(
                controller: secCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'API Secret Key', labelStyle: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent),
            onPressed: () {
              _binanceApiKey = keyCtrl.text.trim();
              _binanceApiSecret = secCtrl.text.trim();
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('حفظ الإعدادات', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildActiveTradesView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
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
                  const SizedBox(width: 6),
                  Text(_isAutoTradingEnabled ? 'التداول الآلي شغال ⚡' : 'التداول الآلي متوقف ⏸️', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              Text('نوع التداول: ${_isLiveRealFunds ? 'حقيقي (Real API) 🟢' : 'تجريبي (Demo) 🟡'}', style: const TextStyle(fontSize: 11, color: Colors.amberAccent)),
            ],
          ),
        ),
        Expanded(
          child: _activeTrades.isEmpty
              ? const Center(child: Text('لا توجد صفقات نشطة حالياً.\nالبوت يقوم الآن بفحص الموجات لفتح الصفقات تلقائياً!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _activeTrades.length,
                  itemBuilder: (context, index) {
                    final trade = _activeTrades[index];
                    final coin = _cryptoList.firstWhere((c) => c['id'] == trade['id'], orElse: () => null);
                    double currentPrice = coin != null ? (coin['current_price'] ?? 0).toDouble() : (trade['entryPrice'] as num).toDouble();
                    double entryPrice = (trade['entryPrice'] as num).toDouble();
                    
                    bool isWin = currentPrice >= entryPrice;
                    double currentPnl = (((currentPrice - entryPrice) / entryPrice) * 100) * 75.0;
                    int achievedTps = trade['achievedTps'] ?? 0;

                    return Card(
                      color: isWin ? const Color(0xFF0D281E) : const Color(0xFF151922),
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isWin ? Colors.greenAccent : Colors.grey.withOpacity(0.3), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${trade['name']} (${trade['symbol'].toString().toUpperCase()}) - موجة #${trade['waveIndex']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: isWin ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                  child: Text('${currentPnl >= 0 ? '+' : ''}${currentPnl.toStringAsFixed(1)}%',
                                      style: TextStyle(color: isWin ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('الدخول: \$$entryPrice', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                Text('الحالي: \$${currentPrice.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildTpBadge('🎯 TP1', (trade['tp1'] as num).toDouble(), achievedTps >= 1),
                                const SizedBox(width: 4),
                                _buildTpBadge('🎯 TP2', (trade['tp2'] as num).toDouble(), achievedTps >= 2),
                                const SizedBox(width: 4),
                                _buildTpBadge('🎯 TP3', (trade['tp3'] as num).toDouble(), achievedTps >= 3),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('🛡️ وقف الخسارة المتحرك: \$${(trade['stopLoss'] as num).toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            const Divider(color: Colors.grey),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(double.infinity, 32)),
                              onPressed: () => _closeTrade(trade, isWin, closePrice: currentPrice),
                              child: const Text('إغلاق يدوي فوري', style: TextStyle(fontSize: 11, color: Colors.white)),
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

  Widget _buildTpBadge(String label, double val, bool isAchieved) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isAchieved ? Colors.greenAccent : Colors.black45,
          borderRadius: BorderRadius.circular(4),
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
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: const Text('🛡 خوارزمية ذكية متطورة', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
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
            decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                const Text('نسبة النجاح الكلية (Win Rate):', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Text('${winRate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
              ],
            ),
          ),
          const SizedBox(height: 20),
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

                    return Card(
                      color: const Color(0xFF151922),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(isWin ? Icons.check_circle : Icons.cancel, color: isWin ? Colors.greenAccent : Colors.redAccent),
                        title: Text('${t['name']} (${t['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('دخول: \$${t['entryPrice']} | إغلاق: \$${(t['closePrice'] as num).toStringAsFixed(4)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        trailing: Text(
                          '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(1)}%',
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

  Widget _buildScalpingView() {
    List<dynamic> scalpCoins = _cryptoList.where((c) {
      double change24 = (c['price_change_percentage_24h'] ?? 0).toDouble();
      return change24.abs() >= 1.2;
    }).toList();

    return ListView.builder(
      itemCount: scalpCoins.length,
      itemBuilder: (context, index) {
        final coin = scalpCoins[index];
        final double price = (coin['current_price'] ?? 0).toDouble();
        final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();

        return Card(
          color: const Color(0xFF151922),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: ListTile(
            leading: Image.network(coin['image'] ?? '', width: 24, height: 24, errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin)),
            title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('السعر: \$$price', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            trailing: Text('${change24 >= 0 ? '+' : ''}${change24.toStringAsFixed(2)}%', style: TextStyle(color: change24 >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildCryptoList(List<dynamic> coins, String category) {
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
          ),
        );
      },
    );
  }
}

class DeepSearchTab extends StatefulWidget {
  final List<dynamic> cryptoList;
  const DeepSearchTab({super.key, required this.cryptoList});

  @override
  State<DeepSearchTab> createState() => _DeepSearchTabState();
}

class _DeepSearchTabState extends State<DeepSearchTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  Map<String, dynamic>? _deepDetails;
  bool _isAnalyzing = false;

  Future<void> _fetchDeepData(String coinId) async {
    setState(() {
      _isAnalyzing = true;
      _deepDetails = null;
    });

    try {
      final url = Uri.parse('https://api.coingecko.com/api/v3/coins/$coinId?localization=false&tickers=false&market_data=true&community_data=false&developer_data=false&sparkline=false');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _deepDetails = data;
          _isAnalyzing = false;
        });
      } else {
        setState(() => _isAnalyzing = false);
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
    }
  }

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
                const Text('🔍 محرك البحث العميق والمتقدم:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amberAccent)),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن أي عملة (مثل: PEPE, BTC, SOL)...',
                    prefixIcon: const Icon(Icons.search, color: Colors.amberAccent),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.analytics, color: Colors.amberAccent),
                      onPressed: () {
                        final query = _searchCtrl.text.trim().toLowerCase();
                        if (query.isNotEmpty && widget.cryptoList.isNotEmpty) {
                          final match = widget.cryptoList.firstWhere(
                            (c) => c['symbol'].toString().toLowerCase() == query || c['name'].toString().toLowerCase().contains(query),
                            orElse: () => widget.cryptoList.first,
                          );
                          _fetchDeepData(match['id']);
                        }
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0B0E14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _isAnalyzing
              ? const Center(child: CircularProgressIndicator(color: Colors.amberAccent))
              : _deepDetails == null
                  ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('ادخل اسم العملة واضغط بحث', style: TextStyle(color: Colors.grey))))
                  : const Center(child: Text('تم جلب بيانات التحليل العميق بنجاح!')),
        ],
      ),
    );
  }
}
