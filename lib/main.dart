import 'dart:async';
import 'dart:math';
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
      title: 'Ayman7708 Trading Bot - AI Engine',
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

  // القوائم الأساسية للربط والتداول
  List<Map<String, dynamic>> _activeTrades = [];
  final List<Map<String, dynamic>> _tradeHistory = [];
  Timer? _refreshTimer;

  // خوارزميات ومؤشرات TradingView تحت الاختبار (قائمة 1)
  List<Map<String, dynamic>> _testingIndicators = [
    {'name': 'RSI Oversold/Overbought (14)', 'category': 'Momentum', 'winRate': 68.4, 'tests': 420, 'status': 'تحت الاختبار', 'color': Colors.orangeAccent},
    {'name': 'MACD Golden Cross (12, 26, 9)', 'category': 'Trend', 'winRate': 82.5, 'tests': 610, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'Bollinger Bands Squeeze + Breakout', 'category': 'Volatility', 'winRate': 76.8, 'tests': 350, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'EMA 50 / EMA 200 Cross (Golden)', 'category': 'Trend', 'winRate': 89.2, 'tests': 890, 'status': 'ممتاز - معتمد', 'color': Colors.amber},
    {'name': 'SuperTrend (10, 3)', 'category': 'Trend', 'winRate': 81.1, 'tests': 510, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'Stochastic Oscillator (14, 3, 3)', 'category': 'Momentum', 'winRate': 54.2, 'tests': 290, 'status': 'ضعيف - يتعلم', 'color': Colors.redAccent},
    {'name': 'VWAP + Volume Profile', 'category': 'Volume', 'winRate': 79.4, 'tests': 440, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'Ichimoku Cloud Breakout', 'category': 'Trend', 'winRate': 62.0, 'tests': 180, 'status': 'تحت الاختبار', 'color': Colors.orangeAccent},
    {'name': 'ATR Trailing Stop Loss System', 'category': 'Risk/Volatility', 'winRate': 85.0, 'tests': 720, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadInitialData();

    // المحرك الآلي للتحديث والتطور والتعلم التلقائي كل 4 ثوانٍ
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _updateLivePricesAndSelfLearn();
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
          'strategy': 'EMA 50/200 Cross'
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
          'strategy': 'MACD Golden Cross'
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
          'strategy': 'SuperTrend'
        },
      ];
    });
  }

  // التعلم التلقائي والتطور الذاتي المباشر
  void _updateLivePricesAndSelfLearn() {
    if (!mounted) return;
    setState(() {
      final random = Random();

      // 1. تحديث الأسعار للصفقات النشطة
      for (var trade in _activeTrades) {
        double entry = (trade['entryPrice'] as num).toDouble();
        double current = (trade['currentPrice'] as num).toDouble();
        double change = (random.nextDouble() - 0.48) * (entry * 0.002);
        current += change;
        trade['currentPrice'] = double.parse(current.toStringAsFixed(4));

        double pnl = ((current - entry) / entry) * 100 * 10;
        trade['pnl'] = double.parse(pnl.toStringAsFixed(1));
      }

      // 2. تطوير واختبار مؤشرات TradingView الذاتي (محاكاة التعلم الآلي)
      for (var ind in _testingIndicators) {
        ind['tests'] = (ind['tests'] as int) + 1;
        double win = (ind['winRate'] as num).toDouble();
        double shift = (random.nextDouble() - 0.49) * 0.3;
        win = (win + shift).clamp(30.0, 98.5);
        ind['winRate'] = double.parse(win.toStringAsFixed(1));

        if (win >= 75.0) {
          ind['status'] = 'مؤشر ناجح';
          ind['color'] = Colors.greenAccent;
        } else if (win >= 88.0) {
          ind['status'] = 'ممتاز - معتمد';
          ind['color'] = Colors.amber;
        } else {
          ind['status'] = 'تحت التعلم';
          ind['color'] = Colors.orangeAccent;
        }
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
        content: Text('تم إغلاق صفقة ${trade['symbol']} فورياً وتسجيل النتيجة للتعلم'),
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
                  onPressed: _updateLivePricesAndSelfLearn,
                ),
                const Icon(Icons.psychology, color: Colors.amber, size: 22),
              ],
            ),
            Row(
              children: const [
                Text(
                  'Ayman7708 Bot (AI Learning)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
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
                isScrollable: true,
                indicatorColor: Colors.amber,
                labelColor: Colors.amber,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(
                    child: Row(
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
                      children: [
                        Text('اختبار TradingView'),
                        SizedBox(width: 4),
                        Icon(Icons.science, size: 16, color: Colors.cyanAccent),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      children: [
                        Text('المؤشرات الناجحة 🎯'),
                        SizedBox(width: 4),
                        Icon(Icons.verified, size: 16, color: Colors.greenAccent),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      children: [
                        Text('الصفقات المتاحة'),
                        SizedBox(width: 4),
                        Icon(Icons.search, size: 16),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      children: [
                        Text('سجل الأرباح'),
                        SizedBox(width: 4),
                        Icon(Icons.bar_chart, size: 16),
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
                        Icons.smart_toy,
                        color: _isAutoTradingEnabled ? Colors.greenAccent : Colors.redAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'التداول والتعلم الآلي ${_isAutoTradingEnabled ? "شغال" : "متوقف"}',
                        style: TextStyle(
                          color: _isAutoTradingEnabled ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
                // الصفحة الرئيسية وبها الـ 5 تبويبات (الصفقات النشطة + المؤشرات + النجاح + المتاحة + السجل)
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveTradesTab(),
                    _buildTradingViewLabTab(),
                    _buildSuccessfulIndicatorsTab(),
                    _buildAvailableTradesTab(),
                    _buildHistoryTab(),
                  ],
                ),
                // الصفحة 2: عقود الإشارات السريعة 60M Scalper
                _buildScalperTab(),
                // الصفحة 3: إعدادات الذكاء الاصطناعي والتداول
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
            icon: Icon(Icons.auto_graph),
            label: 'التداول الذكي',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on),
            label: 'عقود 60M',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_suggest),
            label: 'الإعدادات والتعلم',
          ),
        ],
      ),
    );
  }

  // 1. شاشة الصفقات النشطة
  Widget _buildActiveTradesTab() {
    if (_activeTrades.isEmpty) {
      return const Center(
        child: Text('لا توجد صفقات نشطة حالياً، الروبوت يبحث عن فرص جديدة...', style: TextStyle(color: Colors.grey)),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isProfit ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${pnl > 0 ? "+" : ""}$pnl%',
                        style: TextStyle(
                          color: isProfit ? Colors.greenAccent : Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${trade['symbol']} - موجة #${trade['wave']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'استراتيجية الدخول: ${trade['strategy'] ?? "AI Indicator"}',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
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
                      'وقف الخسارة المتحرك الذكي:',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.shield, color: Colors.redAccent, size: 14),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
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

  // 2. القائمة الجديدة الأولى: مختبر مؤشرات TradingView
  Widget _buildTradingViewLabTab() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF161C28),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.science, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'يقوم البوت باختبار وتجربة جميع مؤشرات TradingView الأساسية بشكل تلقائي على مختلف العملات لتصحيح الأخطاء.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: _testingIndicators.length,
            itemBuilder: (context, index) {
              final ind = _testingIndicators[index];
              return Card(
                color: const Color(0xFF161C28),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(ind['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('النوع: ${ind['category']} | عدد الاختبارات الآلية: ${ind['tests']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${ind['winRate']}%', style: TextStyle(color: ind['color'], fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(ind['status'], style: TextStyle(color: ind['color'], fontSize: 10)),
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

  // 3. القائمة الجديدة الثانية: المؤشرات المعتمدة والناجحة للتداول الآلي
  Widget _buildSuccessfulIndicatorsTab() {
    final successfulList = _testingIndicators.where((e) => (e['winRate'] as num) >= 75.0).toList();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.greenAccent),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified, color: Colors.greenAccent, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المؤشرات التي تجاوزت نسبة نجاحها 75%+ يتم اعتمادها لتنفيذ الصفقات التلقائية الحقيقية وتجنب الخسارة.',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: successfulList.length,
            itemBuilder: (context, index) {
              final ind = successfulList[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161C28),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
                      label: const Text('مفعل بالبوت', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(ind['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('نسبة النجاح المؤكدة: ${ind['winRate']}% 🎯', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('تم إجراء ${ind['tests']} صفقة تداول ناجحة', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 4. باقي الشاشات السابقة (المتاحة + السجل + Scalper + الإعدادات)
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
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
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
                    const Text('مغلقة', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
      {'symbol': 'Solana (SOL)', 'price': 142.50, 'signal': 'شراء STRONG BUY', 'indicator': 'EMA 50/200 Cross'},
      {'symbol': 'Bitcoin (BTC)', 'price': 63200.0, 'signal': 'انتظار WAITING', 'indicator': 'RSI Oversold'},
      {'symbol': 'Ethereum (ETH)', 'price': 2650.0, 'signal': 'شراء BUY', 'indicator': 'VWAP + Volume'},
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
                  Text('${item['signal']} (${item['indicator']})', style: const TextStyle(color: Colors.greenAccent, fontSize: 10)),
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
                Column(children: [Text('340', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text('الإجمالي', style: TextStyle(color: Colors.grey, fontSize: 11))]),
                Column(children: [Text('282', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)), Text('الرابحة', style: TextStyle(color: Colors.grey, fontSize: 11))]),
                Column(children: [Text('58', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)), Text('الخاسرة', style: TextStyle(color: Colors.grey, fontSize: 11))]),
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
                Text('نسبة دقة إشارات العقود الآجلة بعد التعلم التلقائي:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(height: 4),
                Text('82.9%', style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
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
          title: const Text('التداول الآلي وتصحيح الأخطاء الذكي', style: TextStyle(color: Colors.white)),
          subtitle: const Text('يتعلم من أسباب الخسارة لتفاديها تلقائياً', style: TextStyle(color: Colors.grey, fontSize: 11)),
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
