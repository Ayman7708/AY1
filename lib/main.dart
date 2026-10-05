import 'dart:async';
import 'package:flutter/material.dart';

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
      title: 'Ayman7708 Trading Bot',
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
  bool _isDemoMode = true;

  List<Map<String, dynamic>> _activeTrades = [];
  final List<Map<String, dynamic>> _tradeHistory = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();

    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _updateLivePrices();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    setState(() {
      _activeTrades = [
        {
          'id': 'hype',
          'symbol': 'Hyperliquid (HYPE)',
          'wave': 1,
          'entryPrice': 94.98,
          'currentPrice': 94.98,
          'tp1': 95.930,
          'tp2': 97.070,
          'tp3': 98.589,
          'trailingStop': 94.3151,
          'pnl': 0.0,
        },
        {
          'id': 'xmr',
          'symbol': 'Monero (XMR)',
          'wave': 1,
          'entryPrice': 559.64,
          'currentPrice': 559.4300,
          'tp1': 565.236,
          'tp2': 571.952,
          'tp3': 580.906,
          'trailingStop': 555.7225,
          'pnl': -0.4,
        },
        {
          'id': 'ada',
          'symbol': 'Cardano (ADA)',
          'wave': 1,
          'entryPrice': 0.273022,
          'currentPrice': 0.2727,
          'tp1': 0.276,
          'tp2': 0.279,
          'tp3': 0.283,
          'trailingStop': 0.2711,
          'pnl': -1.2,
        },
      ];
    });
  }

  void _updateLivePrices() {
    if (_activeTrades.isEmpty) return;
    setState(() {
      for (var trade in _activeTrades) {
        double entry = (trade['entryPrice'] as num).toDouble();
        double current = (trade['currentPrice'] as num).toDouble();
        double pnl = ((current - entry) / entry) * 100 * 10;
        trade['pnl'] = double.parse(pnl.toStringAsFixed(1));
      }
    });
  }

  void _closeTradeManual(Map<String, dynamic> trade) {
    setState(() {
      _activeTrades.removeWhere((t) => t['id'] == trade['id']);
      _tradeHistory.add({...trade, 'closeTime': DateTime.now().toString()});
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم إغلاق صفقة ${trade['symbol']} فورياً بنجاح'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 2),
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
                  onPressed: _updateLivePrices,
                ),
                const Icon(Icons.sensors, color: Colors.amber, size: 20),
              ],
            ),
            Row(
              children: const [
                Text(
                  'Ayman7708 Trading Bot',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                SizedBox(width: 6),
                Icon(Icons.bolt, color: Colors.amber, size: 22),
              ],
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
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('صفقاتي النشطة', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                          child: Text(
                            '${_activeTrades.length}',
                            style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('سجل وأرباح الصفقات'),
                        SizedBox(width: 4),
                        Icon(Icons.bar_chart, size: 16),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('الصفقات المتاحة'),
                        SizedBox(width: 4),
                        Icon(Icons.search, size: 16),
                      ],
                    ),
                  ),
                ],
              )
            : null,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF161C28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    setState(() => _isDemoMode = !_isDemoMode);
                  },
                  child: Row(
                    children: [
                      Icon(_isDemoMode ? Icons.circle : Icons.check_circle, color: Colors.amber, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        'نوع التداول: ${_isDemoMode ? "(Demo) تجريبي" : "حقيقي"}',
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() => _isAutoTradingEnabled = !_isAutoTradingEnabled);
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.power_settings_new,
                        color: _isAutoTradingEnabled ? Colors.greenAccent : Colors.redAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'التداول الآلي ${_isAutoTradingEnabled ? "شغال" : "متوقف"}',
                        style: TextStyle(
                          color: _isAutoTradingEnabled ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.circle,
                        color: _isAutoTradingEnabled ? Colors.greenAccent : Colors.redAccent,
                        size: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: IndexedStack(
              index: _bottomNavIndex,
              children: [
                // الصفحة 0: التداول الآلي والصفقات النشطة + التبويبات الثلاثة
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveTradesTab(),
                    _buildHistoryTab(),
                    _buildAvailableTradesTab(),
                  ],
                ),
                // الصفحة 1: عقود الإشارات السريعة (Futures Scalper)
                _buildScalperTab(),
                // الصفحة 2: الإعدادات وإدارة الحساب
                _buildSettingsTab(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() {
            _bottomNavIndex = index;
          });
        },
        backgroundColor: const Color(0xFF161C28),
        selectedItemColor: Colors.amber,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: 'التداول الآلي',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on),
            label: 'عقود 60M',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTradesTab() {
    if (_activeTrades.isEmpty) {
      return const Center(
        child: Text('لا توجد صفقات نشطة حالياً', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      itemCount: _activeTrades.length,
      itemBuilder: (context, index) {
        final trade = _activeTrades[index];
        final double pnl = (trade['pnl'] as num).toDouble();
        final bool isProfit = pnl >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161C28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (pnl != 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isProfit ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${pnl > 0 ? "+" : ""}$pnl%',
                              style: TextStyle(
                                color: isProfit ? Colors.greenAccent : Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${trade['symbol']} - موجة #${trade['wave']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الحالي: \$${trade['currentPrice']}',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      'الدخول: \$${trade['entryPrice']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildTpItem('TP3 🎯', '\$${trade['tp3']}'),
                    const SizedBox(width: 6),
                    _buildTpItem('TP2 🎯', '\$${trade['tp2']}'),
                    const SizedBox(width: 6),
                    _buildTpItem('TP1 🎯', '\$${trade['tp1']}'),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '\$${trade['trailingStop']}',
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'وقف الخسارة المتحرك:',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.shield, color: Colors.redAccent, size: 14),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D4D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _closeTradeManual(trade),
                    child: const Text(
                      'إغلاق يدوي فوري',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTpItem(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F131C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return _tradeHistory.isEmpty
        ? const Center(child: Text('لا يوجد سجل صفقات مغلقة حتى الآن', style: TextStyle(color: Colors.grey)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _tradeHistory.length,
            itemBuilder: (context, index) {
              final t = _tradeHistory[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161C28),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('مغلقة', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(t['symbol'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('التاريخ: ${t['closeTime'].toString().split(".")[0]}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
  }

  Widget _buildAvailableTradesTab() {
    final available = [
      {'symbol': 'Solana (SOL)', 'price': 142.50, 'signal': 'شراء STRONG BUY'},
      {'symbol': 'Bitcoin (BTC)', 'price': 63200.0, 'signal': 'انتظار WAITING'},
      {'symbol': 'Ethereum (ETH)', 'price': 2650.0, 'signal': 'شراء BUY'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: available.length,
      itemBuilder: (context, index) {
        final item = available[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161C28),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () {},
                child: const Text('دخول تلقائي', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(item['symbol'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('السعر: \$${item['price']}', style: const TextStyle(color: Colors.amber, fontSize: 12)),
                  Text(item['signal'].toString(), style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScalperTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161C28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                Column(children: [Text('216', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text('الإجمالي', style: TextStyle(color: Colors.grey, fontSize: 11))]),
                Column(children: [Text('99', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)), Text('الرابحة', style: TextStyle(color: Colors.grey, fontSize: 11))]),
                Column(children: [Text('117', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)), Text('الخاسرة', style: TextStyle(color: Colors.grey, fontSize: 11))]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161C28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Text('نسبة دقة إشارات العقود الآجلة السريعة:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(height: 4),
                Text('45.8%', style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('التداول التلقائي الفوري', style: TextStyle(color: Colors.white)),
          value: _isAutoTradingEnabled,
          activeColor: Colors.amber,
          onChanged: (val) => setState(() => _isAutoTradingEnabled = val),
        ),
        SwitchListTile(
          title: const Text('وضع الحساب التجريبي (Demo)', style: TextStyle(color: Colors.white)),
          value: _isDemoMode,
          activeColor: Colors.amber,
          onChanged: (val) => setState(() => _isDemoMode = val),
        ),
      ],
    );
  }
}
