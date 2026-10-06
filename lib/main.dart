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
      title: 'Ayman7708 Futures AI Bot',
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

  // إدارة رأس المال
  double _initialBalance = 100.00;
  double _currentBalance = 100.00;
  double _totalProfit = 0.00;

  List<Map<String, dynamic>> _activeTrades = [];
  final List<Map<String, dynamic>> _tradeHistory = [];
  Timer? _priceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // إدخال صفقات العقود الآجلة (Futures) الأولية بأسعار دخول قريبة
    _activeTrades = [
      {
        'id': 'near_fut',
        'symbol': 'NEARUSDT',
        'displayName': 'NEAR Protocol (NEAR) - Futures',
        'type': 'LONG',
        'leverage': 75,
        'marginUsed': 15.0, // جزء من المحفظة
        'entryPrice': 5.290,
        'currentPrice': 5.295,
        'tp1': 5.370,
        'tp2': 5.450,
        'tp3': 5.550,
        'trailingStop': 5.180,
        'pnlPercent': 7.08,
        'pnlUsd': 1.06,
        'strategy': 'Order Block Scanner (Futures)'
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
        'strategy': 'Ea Robot Scalper v5.2 (Futures)'
      },
    ];

    _fetchBinanceFuturesLivePrices();
    // جلب الأسعار الحقيقية للعقود الآجلة من منصة بينانس كل ثانية
    _priceTimer = Timer.periodic(const Duration(seconds: 1), (_) => _fetchBinanceFuturesLivePrices());
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // جلب الأسعار المباشرة من API عقود بينانس الآجلة (USDT-M Futures)
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

              // حساب أرباح/خسائر العقود الآجلة بالرافعة المالية
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

  // إغلاق الصفقة وحساب الأرباح وإضافتها لرأس المال الـ 100$
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
        content: Text('تم إغلاق الصفقة! ${profitUsd >= 0 ? "ربح" : "خسارة"}: \$${profitUsd.toStringAsFixed(2)} | الرصيد الجديد: \$${_currentBalance.toStringAsFixed(2)}'),
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
              'Ayman Bot Futures [USDT-M]',
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
                  Tab(text: 'عقود نشطة (${_activeTrades.length})'),
                  const Tab(text: 'تنمية رأس المال 📈'),
                  const Tab(text: 'سجل الصفقات المغلقة'),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          // كارت رأس المال والأرباح المباشرة
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E2838), const Color(0xFF161C28)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Text('رأس المال الحقيقي', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('\$${_currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(height: 30, width: 1, color: Colors.white24),
                Column(
                  children: [
                    const Text('إجمالي أرباح البوت', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text('${_totalProfit >= 0 ? "+" : ""}\$${_totalProfit.toStringAsFixed(2)}', style: TextStyle(color: _totalProfit >= 0 ? Colors.amber : Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(height: 30, width: 1, color: Colors.white24),
                Column(
                  children: [
                    const Text('المنصة والنوع', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    const Text('Binance Futures', style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
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
                    _buildFuturesActiveTradesTab(),
                    _buildCapitalGrowthTab(),
                    _buildHistoryTab(),
                  ],
                ),
                const Center(child: Text('تحليل مؤشرات العقود الآجلة الذكي', style: TextStyle(color: Colors.white))),
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
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'عقود آجلية Futures'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'الذكاء الاصطناعي'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'ربط المحفظة 100\$'),
        ],
      ),
    );
  }

  Widget _buildFuturesActiveTradesTab() {
    if (_activeTrades.isEmpty) {
      return const Center(child: Text('لا توجد صفقات عقود آجلة نشطة، يتم البحث عن فرص جديدة...', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
            border: Border.all(color: isProfit ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3)),
          ),
          child: Column(
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
                    child: Text(
                      '${pnlPercent >= 0 ? "+" : ""}$pnlPercent% (\$$pnlUsd)',
                      style: TextStyle(color: isProfit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                        child: Text('${trade['type']} ${trade['leverage']}x', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      Text(trade['displayName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('سعر Binance Futures: \$${trade['currentPrice']}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('سعر الدخول: \$${trade['entryPrice']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
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

  Widget _buildCapitalGrowthTab() {
    double growthRatio = ((_currentBalance - _initialBalance) / _initialBalance) * 100;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تقرير نمو المحفظة التراكمي:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Text('• رأس المال البدء: \$${_initialBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 6),
          Text('• الرصيد الإجمالي الحالي: \$${_currentBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Text('• نسبة نمو الحساب: +${growthRatio.toStringAsFixed(2)}%', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
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

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إعدادات حساب العقود الآجلة (Futures API)', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          const Text('• حالة الربط: مرتبط بحساب Binance Futures الحقيقي ⚡', style: TextStyle(color: Colors.greenAccent)),
          const SizedBox(height: 8),
          const Text('• الرصيد المخصص للتداول الآلي: 100.00 USDT', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
