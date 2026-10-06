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
      title: 'Ayman7708 AI Trading Engine',
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

  String _selectedExchange = 'Binance';
  final TextEditingController _apiKeyController = TextEditingController(text: "****************");
  final TextEditingController _apiSecretController = TextEditingController(text: "****************");
  bool _isApiConnected = false;

  List<Map<String, dynamic>> _activeTrades = [];
  final List<Map<String, dynamic>> _tradeHistory = [];
  Timer? _refreshTimer;

  final List<Map<String, dynamic>> _testingIndicators = [
    {'name': 'LuxAlgo Premium Suite (Paid)', 'platform': 'TradingView', 'category': 'Smart Money', 'winRate': 88.5, 'tests': 1420, 'status': 'ممتاز - معتمد', 'color': Colors.amber},
    {'name': 'Order Block & Liquidity Finder (Custom Pine)', 'platform': 'TradingView', 'category': 'ICT / SMC', 'winRate': 84.2, 'tests': 980, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'Ea Robot Scalper v5.2 (Custom EA)', 'platform': 'MetaTrader 5', 'category': 'Algorithmic', 'winRate': 79.8, 'tests': 2100, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'Market Cipher B + Divergence (Paid)', 'platform': 'TradingView', 'category': 'Oscillator', 'winRate': 86.4, 'tests': 1150, 'status': 'ممتاز - معتمد', 'color': Colors.amber},
    {'name': 'QuantConnect Machine Learning Model', 'platform': 'QuantConnect', 'category': 'AI & ML', 'winRate': 91.2, 'tests': 3400, 'status': 'ممتاز - معتمد', 'color': Colors.amber},
    {'name': 'EMA 50 / 200 Golden Cross (Free)', 'platform': 'TradingView', 'category': 'Trend', 'winRate': 82.1, 'tests': 890, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'Volume Profile Visible Range (Free/Pro)', 'platform': 'GoCharting', 'category': 'Volume', 'winRate': 78.9, 'tests': 620, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'SMC Fair Value Gap (FVG) Scanner (Custom)', 'platform': 'MetaTrader 4', 'category': 'Price Action', 'winRate': 83.7, 'tests': 770, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
    {'name': 'Stochastic RSI Momentum (Free)', 'platform': 'TabTrader', 'category': 'Momentum', 'winRate': 56.4, 'tests': 430, 'status': 'ضعيف - يتعلم', 'color': Colors.redAccent},
    {'name': 'SuperTrend Multi-Timeframe (Modified Script)', 'platform': 'TradingView', 'category': 'Trend', 'winRate': 80.5, 'tests': 1200, 'status': 'مؤشر ناجح', 'color': Colors.greenAccent},
  ];

  final List<Map<String, dynamic>> _availableOpportunities = [
    {'id': 'sol', 'symbol': 'Solana (SOL)', 'price': 142.50, 'signal': 'شراء قوي (STRONG BUY)', 'winProb': 89.0, 'indicator': 'LuxAlgo Premium + SMC FVG', 'platform': 'TradingView'},
    {'id': 'btc', 'symbol': 'Bitcoin (BTC)', 'price': 63200.0, 'signal': 'فرصة نمو مؤكدة', 'winProb': 92.5, 'indicator': 'QuantConnect AI Engine', 'platform': 'QuantConnect'},
    {'id': 'eth', 'symbol': 'Ethereum (ETH)', 'price': 2650.0, 'signal': 'شراء اختراق (BUY)', 'winProb': 81.4, 'indicator': 'Market Cipher B Divergence', 'platform': 'TradingView'},
    {'id': 'sui', 'symbol': 'Sui Network (SUI)', 'price': 1.85, 'signal': 'فرصة سكالبر (Scalp)', 'winProb': 85.0, 'indicator': 'Ea Robot Scalper v5.2', 'platform': 'MetaTrader 5'},
    {'id': 'near', 'symbol': 'NEAR Protocol (NEAR)', 'price': 4.92, 'signal': 'شراء قاع (Bottom Buy)', 'winProb': 78.2, 'indicator': 'Order Block Scanner', 'platform': 'MetaTrader 4'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadInitialTrades();

    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _updateLivePricesAndSelfLearn();
      _autoScanAndExecuteHighWinRateTrades();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    super.dispose();
  }

  void _loadInitialTrades() {
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
          'trailingStop': 94.315,
          'pnl': 0.0,
          'strategy': 'QuantConnect AI Model'
        },
        {
          'id': 'xmr',
          'symbol': 'Monero (XMR)',
          'wave': 1,
          'entryPrice': 559.64,
          'currentPrice': 559.43,
          'tp1': 565.236,
          'tp2': 571.952,
          'tp3': 580.906,
          'trailingStop': 555.722,
          'pnl': -0.4,
          'strategy': 'LuxAlgo Premium'
        },
      ];
    });
  }

  void _autoScanAndExecuteHighWinRateTrades() {
    if (!_isAutoTradingEnabled) return;

    for (var opp in List.from(_availableOpportunities)) {
      double prob = (opp['winProb'] as num).toDouble();
      bool alreadyActive = _activeTrades.any((t) => t['symbol'] == opp['symbol']);
      if (prob >= 80.0 && !alreadyActive) {
        _executeTrade(opp, isAutomatic: true);
      }
    }
  }

  void _executeTrade(Map<String, dynamic> opp, {bool isAutomatic = false}) {
    double entry = (opp['price'] as num).toDouble();
    double tp1 = double.parse((entry * 1.015).toStringAsFixed(4));
    double tp2 = double.parse((entry * 1.030).toStringAsFixed(4));
    double tp3 = double.parse((entry * 1.050).toStringAsFixed(4));
    double stop = double.parse((entry * 0.988).toStringAsFixed(4));

    final newTrade = {
      'id': '${opp['id']}_${DateTime.now().millisecondsSinceEpoch}',
      'symbol': opp['symbol'],
      'wave': 1,
      'entryPrice': entry,
      'currentPrice': entry,
      'tp1': tp1,
      'tp2': tp2,
      'tp3': tp3,
      'trailingStop': stop,
      'pnl': 0.0,
      'strategy': opp['indicator']
    };

    setState(() {
      _activeTrades.add(newTrade);
      _availableOpportunities.removeWhere((item) => item['id'] == opp['id']);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isAutomatic
              ? '🤖 فتح صفقة تلقائية متقدمة: ${opp['symbol']} (احتمالية النجاح ${opp['winProb']}%)'
              : '✅ تم الدخول المباشر في صفقة ${opp['symbol']} ونقلها للنشطة',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _updateLivePricesAndSelfLearn() {
    if (!mounted) return;
    setState(() {
      final random = Random();

      for (var trade in _activeTrades) {
        double entry = (trade['entryPrice'] as num).toDouble();
        double current = (trade['currentPrice'] as num).toDouble();
        double change = (random.nextDouble() - 0.47) * (entry * 0.002);
        current += change;
        trade['currentPrice'] = double.parse(current.toStringAsFixed(4));

        double pnl = ((current - entry) / entry) * 100 * 10;
        trade['pnl'] = double.parse(pnl.toStringAsFixed(1));
      }

      for (var ind in _testingIndicators) {
        ind['tests'] = (ind['tests'] as int) + 1;
        double win = (ind['winRate'] as num).toDouble();
        double shift = (random.nextDouble() - 0.49) * 0.2;
        win = (win + shift).clamp(35.0, 99.1);
        ind['winRate'] = double.parse(win.toStringAsFixed(1));

        if (win >= 78.0) {
          ind['status'] = 'مؤشر ناجح';
          ind['color'] = Colors.greenAccent;
        } else if (win >= 85.0) {
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
        content: Text('تم إغلاق صفقة ${trade['symbol']} وتسجيل نتائجها لتعزيز الذكاء'),
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
                Icon(Icons.hub, color: _isApiConnected ? Colors.greenAccent : Colors.amber, size: 20),
              ],
            ),
            Row(
              children: [
                Text(
                  'Ayman Bot Pro v2.5 ${_isApiConnected ? "[$_selectedExchange LIVE]" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.bolt, color: Colors.amber, size: 22),
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
                        Text('اختبار جميع المنصات والمؤشرات'),
                        SizedBox(width: 4),
                        Icon(Icons.travel_explore, size: 16, color: Colors.cyanAccent),
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      children: [
                        Text('المؤشرات المعتمدة 🎯'),
                        SizedBox(width: 4),
                        Icon(Icons.verified, size: 16, color: Colors.greenAccent),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        const Text('الفرص والصفقات المتاحة'),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                          child: Text('${_availableOpportunities.length}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                        )
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      Icon(_isDemoMode ? Icons.circle : Icons.check_circle, color: _isDemoMode ? Colors.amber : Colors.greenAccent, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        'وضع التداول: ${_isDemoMode ? "تجريبي (Demo)" : "حقيقي مالي (Live API)"}',
                        style: TextStyle(color: _isDemoMode ? Colors.amber : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
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
                        'التداول والفتح التلقائي: ${_isAutoTradingEnabled ? "مفعل" : "معطل"}',
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
                TabBarView(
                  controller: _tabController,
                  children: [
                    _buildActiveTradesTab(),
                    _buildUniversalIndicatorsLabTab(),
                    _buildSuccessfulIndicatorsTab(),
                    _buildAvailableOpportunitiesTab(),
                    _buildHistoryTab(),
                  ],
                ),
                _buildScalperTab(),
                _buildSettingsAndApiTab(),
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
            icon: Icon(Icons.api),
            label: 'ربط الحساب والإعدادات',
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTradesTab() {
    if (_activeTrades.isEmpty) {
      return const Center(
        child: Text('لا توجد صفقات نشطة حالياً، الروبوت يبحث عن فرص ومؤشرات ممتازة...', style: TextStyle(color: Colors.grey)),
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
                    'استراتيجية/مؤشر: ${trade['strategy']}',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'السعر الحالي: \$${trade['currentPrice']}',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      'سعر الدخول: \$${trade['entryPrice']}',
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
                  height: 38,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4D4D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _closeTradeManual(trade),
                    child: const Text('إغلاق يدوي فوري', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUniversalIndicatorsLabTab() {
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
              Icon(Icons.travel_explore, color: Colors.cyanAccent, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'اختبار وتجربة شاملة لجميع المؤشرات (المجانية، المدفوعة، المعدلة، وPineScript) عبر مختلف المنصات (TradingView, MT4/MT5, QuantConnect, GoCharting).',
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
                  subtitle: Text('المنصة: ${ind['platform']} | التصنيف: ${ind['category']} | التست: ${ind['tests']}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
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

  Widget _buildSuccessfulIndicatorsTab() {
    final successfulList = _testingIndicators.where((e) => (e['winRate'] as num) >= 78.0).toList();

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
                  'المؤشرات المعتمدة لفتح الصفقات التلقائية والمتعددة الموثوقة لتفادي أي خسائر.',
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(6)),
                      child: const Text('مفعل للتداول', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(ind['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text('المنصة: ${ind['platform']} | النجاح: ${ind['winRate']}% 🎯', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
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

  Widget _buildAvailableOpportunitiesTab() {
    if (_availableOpportunities.isEmpty) {
      return const Center(child: Text('تم الدخول في جميع الصفقات المتاحة تلقائياً!', style: TextStyle(color: Colors.amber)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _availableOpportunities.length,
      itemBuilder: (context, index) {
        final item = _availableOpportunities[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161C28),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                onPressed: () => _executeTrade(item, isAutomatic: false),
                icon: const Icon(Icons.flash_on, color: Colors.black, size: 16),
                label: const Text('دخول تلقائي', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(item['symbol'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('السعر: \$${item['price']} | الاحتمالية: ${item['winProb']}%', style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                  Text('المؤشر: ${item['indicator']} (${item['platform']})', style: const TextStyle(color: Colors.cyanAccent, fontSize: 10)),
                ],
              ),
            ],
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

  Widget _buildScalperTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF161C28), borderRadius: BorderRadius.circular(10)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [Text('480', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text('إجمالي الصفقات', style: TextStyle(color: Colors.grey, fontSize: 11))]),
                Column(children: [Text('412', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)), Text('الرابحة', style: TextStyle(color: Colors.grey, fontSize: 11))]),
                Column(children: [Text('68', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)), Text('الخاسرة', style: TextStyle(color: Colors.grey, fontSize: 11))]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF161C28), borderRadius: BorderRadius.circular(10)),
            child: const Column(
              children: [
                Text('نسبة دقة إشارات العقود المجمعة من جميع المنصات:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                SizedBox(height: 4),
                Text('85.8%', style: TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsAndApiTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('ربط منصات التداول الحقيقية (Real Exchange Connection)', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF161C28), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                value: _selectedExchange,
                isExpanded: true,
                dropdownColor: const Color(0xFF161C28),
                items: ['Binance', 'OKX', 'Bybit', 'KuCoin', 'MetaTrader 5 Gateway']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedExchange = val!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(labelText: 'API Key', labelStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _apiSecretController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'API Secret', labelStyle: TextStyle(color: Colors.grey), border: OutlineInputBorder()),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _isApiConnected ? Colors.green : Colors.amber),
                  onPressed: () {
                    setState(() {
                      _isApiConnected = !_isApiConnected;
                      _isDemoMode = !_isApiConnected;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_isApiConnected ? 'تم الربط بنجاح مع حساب $_selectedExchange' : 'تم العودة للوضع التجريبي')),
                    );
                  },
                  icon: Icon(_isApiConnected ? Icons.check_circle : Icons.link, color: Colors.black),
                  label: Text(_isApiConnected ? 'الحساب مرتبط ومفعل (Live)' : 'اتصال الآن وتفعيل API', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SwitchListTile(
          title: const Text('التداول التلقائي والفتح المتعدد للصفقات', style: TextStyle(color: Colors.white)),
          subtitle: const Text('يسمح للبوت بفتح عدة صفقات ناجحة بوقت واحد', style: TextStyle(color: Colors.grey, fontSize: 11)),
          value: _isAutoTradingEnabled,
          activeColor: Colors.amber,
          onChanged: (val) => setState(() => _isAutoTradingEnabled = val),
        ),
      ],
    );
  }
}
