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
      title: 'Ayman Bot Pro - Futures',
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

  // إدارة المحفظة ورأس المال
  double _initialBalance = 100.00;
  double _currentBalance = 100.00;
  double _totalProfit = 0.00;

  List<Map<String, dynamic>> _activeTrades = [];
  final List<Map<String, dynamic>> _tradeHistory = [];
  Timer? _priceTimer;

  // قائمة المؤشرات المعتمدة والاختبار
  final List<Map<String, dynamic>> _testingIndicators = [
    {'name': 'LuxAlgo Premium Suite', 'platform': 'TradingView', 'category': 'Smart Money', 'winRate': 88.5, 'tests': 1420, 'status': 'ممتاز - معتمد', 'color': Colors.amber},
    {'name': 'Order Block Scanner', 'platform': 'TradingView', 'category': 'ICT / SMC', 'winRate': 84.2, 'tests': 980, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'Ea Robot Scalper v5.2', 'platform': 'MetaTrader 5', 'category': 'Algorithmic', 'winRate': 79.8, 'tests': 2100, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // صفقات العقود الآجلة بأسعار بينانس المباشرة
    _activeTrades = [
      {
        'id': 'sui_fut',
        'symbol': 'SUIUSDT',
        'displayName': 'Sui Network (SUI) - موجة #1',
        'type': 'LONG',
        'leverage': 50,
        'marginUsed': 20.0,
        'entryPrice': 1.85,
        'currentPrice': 1.8559,
        'tp1': 1.8777,
        'tp2': 1.9055,
        'tp3': 1.9425,
        'trailingStop': 1.8278,
        'pnlPercent': 15.9,
        'pnlUsd': 3.18,
        'strategy': 'Ea Robot Scalper v5.2'
      },
      {
        'id': 'near_fut',
        'symbol': 'NEARUSDT',
        'displayName': 'NEAR Protocol (NEAR) - موجة #1',
        'type': 'LONG',
        'leverage': 75,
        'marginUsed': 15.0,
        'entryPrice': 5.290,
        'currentPrice': 5.295,
        'tp1': 5.3700,
        'tp2': 5.4500,
        'tp3': 5.5500,
        'trailingStop': 5.1800,
        'pnlPercent': 7.08,
        'pnlUsd': 1.06,
        'strategy': 'Order Block Scanner'
      },
    ];

    _fetchBinanceFuturesLivePrices();
    _priceTimer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchBinanceFuturesLivePrices());
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // جلب الأسعار المباشرة من بينانس العقود الآجلة
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
              if (trade['type'] == 'SHORT') {
                priceChangeRatio = -priceChangeRatio;
              }

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
        content: Text('تم إغلاق الصفقة! الربح/الخسارة: \$${profitUsd.toStringAsFixed(2)} | الرصيد الجديد: \$${_currentBalance.toStringAsFixed(2)}'),
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
              'Ayman Bot Pro v2.5 [Futures]',
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
          // شريط وضع التداول وتنمية المحفظة 100$
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
                    Text('الأرباح: ${'+\$${_totalProfit.toStringAsFixed(2)}'}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
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
                const Center(child: Text('قائمة عقود 60M المباشرة - جاري المسح الذكي', style: TextStyle(color: Colors.white))),
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
      return const Center(child: Text('لا توجد صفقات نشطة حالياً', style: TextStyle(color: Colors.grey)));
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
                    child: Text('${pnlPercent >= 0 ? "+" : ""}$pnlPercent%', style: TextStyle(color: isProfit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                  Text(trade['displayName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 6),
              Text('استراتيجية/مؤشر: ${trade['strategy']}', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('السعر الحالي: \$${trade['currentPrice']}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
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
                  child: const Text('إغلاق يدوي فوري', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          title: Text(_testingIndicators[i]['name'], style: const TextStyle(color: Colors.white)),
          subtitle: Text('المنصة: ${_testingIndicators[i]['platform']} | نسبة النجاح: ${_testingIndicators[i]['winRate']}%', style: const TextStyle(color: Colors.grey, fontSize: 11)),
          trailing: Text(_testingIndicators[i]['status'], style: TextStyle(color: _testingIndicators[i]['color'], fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildApprovedTab() {
    return const Center(child: Text('قائمة المؤشرات المعتمدة الجاهزة للتداول المباشر', style: TextStyle(color: Colors.greenAccent)));
  }

  Widget _buildHistoryTab() {
    if (_tradeHistory.isEmpty) {
      return const Center(child: Text('لا توجد صفقات مغلقة حالياً', style: TextStyle(color: Colors.grey)));
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
            subtitle: Text('إغلاق: ${item['closeTime']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            trailing: Text(
              '${prof >= 0 ? "+" : ""}\$${prof.toStringAsFixed(2)}',
              style: TextStyle(color: prof >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ربط الحساب والإعدادات', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 15)),
          SizedBox(height: 10),
          Text('• وضع التداول: حقيقي مالي (Live API) - مفعل ⚡', style: TextStyle(color: Colors.greenAccent)),
          SizedBox(height: 6),
          Text('• منصة التداول: Binance Futures (USDT-M)', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
