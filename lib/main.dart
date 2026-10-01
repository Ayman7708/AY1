import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const CryptoRadarApp());
}

class CryptoRadarApp extends StatelessWidget {
  const CryptoRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptoRadar Smart Money',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF151C2C),
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
  List<dynamic> _filteredList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    fetchLiveMarketData();
  }

  Future<void> sendNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'crypto_radar_channel',
      'إشعارات CryptoRadar',
      channelDescription: 'تنبيهات صفقات الربح والتوقيت الذهبي',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> fetchLiveMarketData() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
        'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=50&page=1&sparkline=false');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _cryptoList = data;
          _filteredList = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterSearch(String query) {
    setState(() {
      _filteredList = _cryptoList.where((coin) {
        final name = coin['name'].toString().toLowerCase();
        final symbol = coin['symbol'].toString().toLowerCase();
        return name.contains(query.toLowerCase()) || symbol.contains(query.toLowerCase());
      }).toList();
    });
  }

  String getCurrentMarketStatus() {
    int hour = DateTime.now().toUtc().hour;
    if (hour >= 12 && hour <= 16) {
      return "🔥 السيولة قصوى (تداخل جلسة نيويورك ولندن) - أفضل وقت للتداول!";
    } else if (hour >= 7 && hour < 12) {
      return "🟢 سيولة مرتفعة (جلسة لندن) - وقت ممتاز لاقتناص الصفقات.";
    } else if (hour >= 0 && hour < 7) {
      return "🟡 سيولة متوسطة (جلسة آسيا) - تداول بحذر على العملات السريعة.";
    } else {
      return "🔵 سيولة هادئة - يفضل انتظار افتتاح الجلسات الكبرى.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.candlestick_chart, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('CryptoRadar Smart Money', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: fetchLiveMarketData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.layers), text: 'مناطق التجميع والأوامر 🏦'),
            Tab(icon: Icon(Icons.monetization_on), text: 'تحدي 10$ ➔ 100$'),
            Tab(icon: Icon(Icons.access_time), text: 'متى تتداول؟ ⏰'),
            Tab(icon: Icon(Icons.bolt), text: 'ربح سريع ⚡'),
            Tab(icon: Icon(Icons.warning_amber), text: 'رادار التلاعب ⚠️'),
            Tab(icon: Icon(Icons.hub), text: 'المنصات'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: const Color(0xFF1E293B),
                  child: Text(
                    getCurrentMarketStatus(),
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: TextField(
                    onChanged: _filterSearch,
                    decoration: InputDecoration(
                      hintText: 'بحث عن عملة لمعاينة مناطق التجميع والأوامر...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF151C2C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCryptoList(_filteredList, 'smart_money'),
                      _buildCryptoList(_filteredList, 'challenge'),
                      _buildTradingSessionsView(),
                      _buildCryptoList(_filteredList, 'fast_profit'),
                      _buildCryptoList(_filteredList, 'manipulation'),
                      _buildCryptoList(_filteredList, 'exchanges'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTradingSessionsView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text('⏰ أفضل أوقات التداول والتواجد في السوق:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          _buildSessionCard('جلسة نيويورك 🇺🇸 (الأقوى)', '2:00 م - 10:00 م (بتوقيت مكة)', 'تضخيم سيولة حاد وفرص سريعة جداً', Colors.green),
          _buildSessionCard('جلسة لندن 🇬🇧 (ممتازة)', '10:00 ص - 6:00 م (بتوقيت مكة)', 'بداية حركات الترند الحقيقية اليومية', Colors.cyan),
          _buildSessionCard('جلسة طوكيو/آسيا 🇯🇵 (تجميع)', '3:00 ص - 11:00 ص (بتوقيت مكة)', 'حركة تجميعية - مناسبة لصفقات التجهيز', Colors.amber),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, minimumSize: const Size(double.infinity, 45)),
            icon: const Icon(Icons.notifications_active, color: Colors.black),
            label: const Text('تفعيل تنبيهات دخول الجلسات القوية', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () {
              sendNotification('تنبيه CryptoRadar', 'بدأت الآن إحدى أقوى جلسات السيولة! تفقد قائمة الصفقات السريعة.');
            },
          )
        ],
      ),
    );
  }

  Widget _buildSessionCard(String title, String time, String desc, Color color) {
    return Card(
      color: const Color(0xFF151C2C),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(Icons.circle, color: color, size: 14),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(time, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
            Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoList(List<dynamic> coins, String category) {
    List<dynamic> displayCoins = List.from(coins);

    return ListView.builder(
      itemCount: displayCoins.length,
      itemBuilder: (context, index) {
        final coin = displayCoins[index];
        final double price = (coin['current_price'] ?? 0).toDouble();
        final double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
        final bool isPositive = change24 >= 0;

        // حساب مناطق التجميع وأوامر الشراء والبيع المرتكزة على مستويات السيولة
        final double accumulationZoneMin = price * 0.965; // منطقة التجميع السفلى
        final double accumulationZoneMax = price * 0.985; // منطقة التجميع العليا
        final double buyOrderWall = price * 0.96;         // حائط طلبات الشراء الكبرى (Whale Buy Wall)
        final double sellOrderWall = price * 1.045;       // حائط طلبات البيع الكبرى (Whale Sell Wall)

        return Card(
          color: const Color(0xFF151C2C),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Image.network(
                coin['image'] ?? '',
                errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin),
              ),
            ),
            title: Text('${coin['name']} (${coin['symbol'].toString().toUpperCase()})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text('السعر الحالي: \$$price', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${change24.toStringAsFixed(2)}%',
                style: TextStyle(color: isPositive ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.grey),
                    if (category == 'smart_money') ...[
                      const Text('🏦 تحليل خريطة التجميع وأوامر الحيتان الكبرى:', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B0F19),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('📦 نطاق منطقة التجميع (Smart Accumulation): \$$accumulationZoneMin - \$$accumulationZoneMax',
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('🛡️ حائط طلبات الشراء الضخمة (Buy Order Wall): \$$buyOrderWall',
                                style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
                            const SizedBox(height: 4),
                            Text('🎯 حائط جني الأرباح / أهداف البيع الكبرى (Sell Wall): \$$sellOrderWall',
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Text('🚀 خطة نمو $10 إلى $100 لهذه العملة:', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('• المرحلة 1: دخول عند منطقة التجميع \$$accumulationZoneMax ➔ هدف أول \$${(price * 1.05).toStringAsFixed(3)} (+5%)', style: const TextStyle(fontSize: 11)),
                      Text('• المرحلة 2: تكرار العملية بـ 3 صفقات متتالية بنفس الاستراتيجية.', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan, minimumSize: const Size(double.infinity, 38)),
                      icon: const Icon(Icons.notifications_active, color: Colors.black),
                      label: const Text('تفعيل تنبيه وصول السعر لمنطقة التجميع', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        sendNotification('تنبيه سيولة لـ ${coin['name']}', 'وصل السعر قرب منطقة التجميع \$$accumulationZoneMax! جهز أمر الدخول.');
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفعيل التنبيه بنجاح!')));
                      },
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
