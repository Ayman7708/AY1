import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AymanTradingBotApp());
}

class AymanTradingBotApp extends StatelessWidget {
  const AymanTradingBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ayman Bot Pro',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F131C),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161C28),
          elevation: 0,
        ),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _bottomNavIndex = 0;
  bool _isAutoTradingEnabled = true;
  bool _isDemoMode = false;

  // إعدادات المحفظة ورأس المال
  double _initialBalance = 100.00;
  double _currentBalance = 100.00;
  double _totalProfit = 0.00;

  // بيانات الربط والـ API
  String _selectedExchange = 'Binance Futures';
  final TextEditingController _apiKeyController = TextEditingController(text: "****************");
  final TextEditingController _apiSecretController = TextEditingController(text: "****************");
  bool _isApiConnected = true;

  List<Map<String, dynamic>> _activeTrades = [];
  final List<Map<String, dynamic>> _tradeHistory = [];
  Timer? _priceTimer;

  // قائمة عقود 60M
  final List<Map<String, dynamic>> _contracts60m = [
    {'symbol': 'BTCUSDT', 'displayName': 'Bitcoin (BTC)', 'change': '+3.4%', 'signal': 'شراء قوي (BUY)', 'rsi': 62, 'volume': '1.2B'},
    {'symbol': 'ETHUSDT', 'displayName': 'Ethereum (ETH)', 'change': '+1.8%', 'signal': 'شراء (BUY)', 'rsi': 58, 'volume': '840M'},
    {'symbol': 'SOLUSDT', 'displayName': 'Solana (SOL)', 'change': '-0.5%', 'signal': 'محايد (HOLD)', 'rsi': 49, 'volume': '410M'},
    {'symbol': 'NEARUSDT', 'displayName': 'NEAR Protocol (NEAR)', 'change': '+4.2%', 'signal': 'اختراق صاعد (BREAKOUT)', 'rsi': 68, 'volume': '180M'},
    {'symbol': 'SUIUSDT', 'displayName': 'Sui Network (SUI)', 'change': '+5.1%', 'signal': 'شراء قوي (BUY)', 'rsi': 71, 'volume': '230M'},
  ];

  // قائمة اختبار المؤشرات
  final List<Map<String, dynamic>> _testingIndicators = [
    {'name': 'LuxAlgo Premium Suite', 'platform': 'TradingView', 'category': 'Smart Money', 'winRate': 88.5, 'tests': 1420, 'status': 'ممتاز - معتمد', 'color': Colors.amber},
    {'name': 'Order Block Scanner', 'platform': 'TradingView', 'category': 'ICT / SMC', 'winRate': 84.2, 'tests': 980, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'Ea Robot Scalper v5.2', 'platform': 'MetaTrader 5', 'category': 'Algorithmic', 'winRate': 79.8, 'tests': 2100, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'ICT Liquidity Grabber', 'platform': 'TradingView', 'category': 'Smart Money', 'winRate': 76.4, 'tests': 650, 'status': 'قيد الاختبار', 'color': Colors.orangeAccent},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // الصفقات الحالية مع نظام العقود الآجلة
    _activeTrades = [
      {
        'id': 'near_fut',
        'symbol': 'NEARUSDT',
        'displayName': 'NEAR Protocol (NEAR) - Futures',
        'type': 'LONG',
        'leverage': 75,
        'marginUsed': 15.0,
        'entryPrice': 5.290,
        'currentPrice': 5.295,
        'tp1': 5.370,
        'tp2': 5.450,
        'tp3': 5.550,
        'trailingStop': 5.180,
        'pnlPercent': 7.08,
        'pnlUsd': 1.06,
        'strategy': 'Order Block Scanner'
      },
      {
        'id': 'sui_fut',
        'symbol': 'SUIUSDT',
        'displayName': 'Sui Network (SUI) - Futures',
        'type': 'LONG',
        'leverage': 50,
        'marginUsed': 20.0,
        'entryPrice': 1.845,
        'currentPrice': 1.855,
        'tp1': 1.880,
        'tp2': 1.910,
        'tp3': 1.950,
        'trailingStop': 1.820,
        'pnlPercent': 27.10,
        'pnlUsd': 5.42,
        'strategy': 'Ea Robot Scalper v5.2'
      },
    ];

    _fetchBinanceFuturesLivePrices();
    _priceTimer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchBinanceFuturesLivePrices());
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    _tabController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    super.dispose();
  }

  // تحديث أسعار العقود الآجلة المباشرة من Binance API
  Future<void> _fetchBinanceFuturesLivePrices() async {
    try {
      final response = await http.get(Uri.parse('https://fapi.binance.com/fapi/v1/ticker/price'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final Map<String, double> livePrices = {};
        
        for (var item in data) {
          livePrices[item['symbol']] = double.parse(item['price']);
        }

        if (!mounted) return;
        setState(() {
          for (var trade in _activeTrades) {
            String sym = trade['symbol'];
            if (livePrices.containsKey(sym)) {
              double livePrice = livePrices[sym]!;
              trade['currentPrice'] = livePrice;
              
              double entry = (trade['entryPrice'] as num).toDouble();
              int lev = (trade['leverage'] as num).toInt();
              double margin = (trade['marginUsed'] as num).toDouble();

              double priceChangeRatio = (livePrice - entry) / entry;
              if (trade['type'] == 'SHORT') priceChangeRatio = -priceChangeRatio;

              double pnlPercent = priceChangeRatio * lev * 100;
              double pnlUsd = margin * (priceChangeRatio * lev);

              trade['pnlPercent'] = double.parse(pnlPercent.toStringAsFixed(2));
              trade['pnlUsd'] = double.parse(pnlUsd.toStringAsFixed(2));
            }
          }
        });
      }
    } catch (_) {}
  }

  void _closeTrade(Map<String, dynamic> trade) {
    double profitUsd = (trade['pnlUsd'] as num).toDouble();

    setState(() {
      _currentBalance += profitUsd;
      _totalProfit += profitUsd;
      _activeTrades.removeWhere((t) => t['id'] == trade['id']);
      _tradeHistory.add({
        ...trade,
        'closeTime': DateTime.now().toString().split('.')[0],
        'finalProfitUsd': profitUsd
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إغلاق الصفقة! الربح: \$${profitUsd.toStringAsFixed(2)} | الرصيد الجديد: \$${_currentBalance.toStringAsFixed(2)}'),
        backgroundColor: profitUsd >= 0 ? Colors.green : Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.amber),
                  onPressed: _fetchBinanceFuturesLivePrices,
                ),
                const Icon(Icons.verified, color: Colors.greenAccent, size: 18),
              ],
            ),
            const Text(
              'Ayman Bot Pro [Futures]',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
            ),
          ],
        ),
        bottom: _bottomNavIndex == 0
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                labelColor: Colors.amber,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'صفقاتي النشطة (${_activeTrades.length})'),
                  const Tab(text: 'اختبار المؤشرات'),
                  const Tab(text: 'المؤشرات المعتمدة'),
                  const Tab(text: 'سجل الأرباح'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // شريط رأس المال والأرباح والربط
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF161C28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('الرصيد: \$${_currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.trending_up, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('الربح التراكمي: ${'+\$${_totalProfit.toStringAsFixed(2)}'}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Text('Binance Futures Live', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _bottomNavIndex,
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveTradesTab(),
                    _buildIndicatorsTab(),
                    _buildApprovedTab(),
                    _buildHistoryTab(),
                  ],
                ),
                _build60mContractsTab(),
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (i) => setState(() => _bottomNavIndex = i),
        backgroundColor: const Color(0xFF161C28),
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.auto_graph), label: 'التداول الذكي'),
          BottomNavigationBarItem(icon: Icon(Icons.flash_on), label: 'عقود 60M'),
          BottomNavigationBarItem(icon: Icon(Icons.api), label: 'ربط الحساب'),
        ],
      ),
    );
  }

  Widget _buildActiveTradesTab() {
    if (_activeTrades.isEmpty) {
      return const Center(child: Text('لا توجد صفقات نشطة حالياً، يتم البحث عن فرص...', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _activeTrades.length,
      itemBuilder: (context, index) {
        final trade = _activeTrades[index];
        final double pnlPercent = (trade['pnlPercent'] as num).toDouble();
        final double pnlUsd = (trade['pnlUsd'] as num).toDouble();
        final bool isProfit = pnlUsd >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161C28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isProfit ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${pnlPercent >= 0 ? "+" : ""}$pnlPercent% (\$$pnlUsd)', style: TextStyle(color: isProfit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                        child: Text('${trade['type']} ${trade['leverage']}x', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                      const SizedBox(width: 6),
                      Text(trade['displayName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('المؤشر: ${trade['strategy']}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('السعر المباشر: \$${trade['currentPrice']}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('سعر الدخول: \$${trade['entryPrice']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('TP1: \$${trade['tp1']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('TP2: \$${trade['tp2']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('TP3: \$${trade['tp3']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D4D)),
                  onPressed: () => _closeTrade(trade),
                  child: const Text('إغلاق الصفقة وإضافة الربح لرأس المال', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIndicatorsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _testingIndicators.length,
      itemBuilder: (c, i) => Card(
        color: const Color(0xFF161C28),
        child: ListTile(
          title: Text(_testingIndicators[i]['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('المنصة: ${_testingIndicators[i]['platform']} | نسبة النجاح: ${_testingIndicators[i]['winRate']}%', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          trailing: Text(_testingIndicators[i]['status'], style: TextStyle(color: _testingIndicators[i]['color'], fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildApprovedTab() {
    final approved = _testingIndicators.where((e) => e['status'].contains('معتمد') || e['status'].contains('ناجح')).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: approved.length,
      itemBuilder: (c, i) => Card(
        color: const Color(0xFF161C28),
        child: ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.greenAccent),
          title: Text(approved[i]['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text('فئة التداول: ${approved[i]['category']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          trailing: Text('${approved[i]['winRate']}% WinRate', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_tradeHistory.isEmpty) {
      return const Center(child: Text('لا توجد صفقات مغلقة حتى الآن', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _tradeHistory.length,
      itemBuilder: (context, index) {
        final item = _tradeHistory[index];
        double prof = (item['finalProfitUsd'] as num).toDouble();
        return Card(
          color: const Color(0xFF161C28),
          child: ListTile(
            title: Text(item['displayName'], style: const TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text('تاريخ الإغلاق: ${item['closeTime']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            trailing: Text(
              '${prof >= 0 ? "+" : ""}\$${prof.toStringAsFixed(2)}',
              style: TextStyle(color: prof >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _build60mContractsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _contracts60m.length,
      itemBuilder: (context, index) {
        final contract = _contracts60m[index];
        return Card(
          color: const Color(0xFF161C28),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(contract['displayName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('RSI: ${contract['rsi']} | السيولة: ${contract['volume']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(contract['signal'], style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
                const SizedBox(height: 2),
                Text(contract['change'], style: TextStyle(color: contract['change'].startsWith('+') ? Colors.greenAccent : Colors.redAccent, fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إعدادات ربط المنصة وحساب العقود (API Settings)', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          const Text('• حالة الاتصال: مرتبط بـ Binance Futures API ⚡', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('• رأس المال التراكمي المخصص: \$${_currentBalance.toStringAsFixed(2)} USDT', style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(labelText: 'API Key', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiSecretController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API Secret', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}
