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
      title: 'CryptoRadar AI',
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
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
    _tabController = TabController(length: 3, vsync: this);
    fetchLiveCryptoData();
  }

  // إرسال إشعار للمستخدم بالصفقة
  Future<void> sendNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'crypto_radar_channel',
      'تنبيهات صفقات CryptoRadar',
      channelDescription: 'إشعارات صفقات الذكاء الاصطناعي وتجمعات الحيتان',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
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

  // جلب أسعار وبيانات السوق الحية
  Future<void> fetchLiveCryptoData() async {
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

  // خوارزمية الذكاء الاصطناعي لحساب نسبة نجاح الصفقة (Win-Rate %)
  double calculateAISuccessRate(dynamic coin) {
    double change24 = (coin['price_change_percentage_24h'] ?? 0).toDouble();
    double vol = (coin['total_volume'] ?? 0).toDouble();
    double cap = (coin['market_cap'] ?? 1).toDouble();
    double volCapRatio = vol / cap;

    double baseScore = 60.0; // النسبة الأساسية
    if (change24 > 0) baseScore += (change24 * 1.5);
    if (volCapRatio > 0.1) baseScore += 15.0;
    if (volCapRatio > 0.25) baseScore += 10.0;

    if (baseScore > 96.0) return 96.0;
    if (baseScore < 45.0) return 48.5;
    return double.parse(baseScore.toStringAsFixed(1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.cyanAccent),
            SizedBox(width: 8),
            Text('CryptoRadar AI Hub', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
            onPressed: fetchLiveCryptoData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'صفقات الذكاء الاصطناعي'),
            Tab(icon: Icon(Icons.waves), text: 'تجميع الحيتان'),
            Tab(icon: Icon(Icons.bolt), text: 'الانفجارات القادمة'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    onChanged: _filterSearch,
                    decoration: InputDecoration(
                      hintText: 'بحث عن عملة للمعاينة والتنفيذ...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
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
                      _buildCryptoList(_filteredList, 'ai_signals'),
                      _buildCryptoList(_filteredList, 'whales'),
                      _buildCryptoList(_filteredList, 'breakout'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCryptoList(List<dynamic> coins, String type) {
    List<dynamic> displayCoins = List.from(coins);

    if (type == 'whales') {
      displayCoins = displayCoins.where((c) {
        double vol = (c['total_volume'] ?? 0).toDouble();
        double cap = (c['market_cap'] ?? 1).toDouble();
        return (vol / cap) > 0.15;
      }).toList();
    } else if (type == 'breakout') {
      displayCoins = displayCoins.where((c) {
        double change = (c['price_change_percentage_24h'] ?? 0).toDouble();
        return change > 3.0;
      }).toList();
    }

    return ListView.builder(
      itemCount: displayCoins.length,
      itemBuilder: (context, index) {
        final coin = displayCoins[index];
        final price = coin['current_price'] ?? 0;
        final change24 = coin['price_change_percentage_24h'] ?? 0;
        final bool isPositive = change24 >= 0;
        final double aiSuccessRate = calculateAISuccessRate(coin);

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.transparent,
              child: Image.network(
                coin['image'] ?? '',
                errorBuilder: (_, __, ___) => const Icon(Icons.currency_bitcoin),
              ),
            ),
            title: Row(
              children: [
                Text(
                  '${coin['name']} ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'نجاح: $aiSuccessRate%',
                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              'السعر الحقيقي: \$$price',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPositive ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${change24.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.grey),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('تقييم نماذج الذكاء الاصطناعي: ${aiSuccessRate > 75 ? "توصية عالية الثقة 🟢" : "توصية متوسطة المخاطرة 🟡"}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // تفاصيل الصفقات
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('⚡ صفقة قصيرة (Scalp): دخول \$$price - هدف الأول \$${(price * 1.03).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('🎯 صفقة طويلة (Investment): نطاق تجميع ممتاز - الهدف المستقبلي \$${(price * 1.25).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // زر إرسال التنبيه
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                      icon: const Icon(Icons.notifications_active, color: Colors.black),
                      label: const Text('إرسال تنبيه بالصفقة إلى هاتفي', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        sendNotification(
                          'CryptoRadar AI: صفقة متوقعة لـ ${coin['name']}',
                          'نسبة النجاح: $aiSuccessRate% | السعر الحقيقي: \$$price | الهدف الأول: \$${(price * 1.03).toStringAsFixed(2)}',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إرسال التنبيه إلى شريط الإشعارات!')),
                        );
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
