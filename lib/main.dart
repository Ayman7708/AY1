import 'package:flutter/material.dart';

void main() {
  runApp(const CryptoRadarApp());
}

class CryptoRadarApp extends StatelessWidget {
  const CryptoRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CryptoRadar',
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

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> cryptoData = [
    {
      'name': 'Bitcoin',
      'symbol': 'BTC',
      'price': '\$64,250.00',
      'change': '+2.45%',
      'isPositive': true,
      'icon': Icons.currency_bitcoin,
      'color': Colors.orange,
    },
    {
      'name': 'Ethereum',
      'symbol': 'ETH',
      'price': '\$3,480.50',
      'change': '+1.82%',
      'isPositive': true,
      'icon': Icons.currency_exchange,
      'color': Colors.blueAccent,
    },
    {
      'name': 'Solana',
      'symbol': 'SOL',
      'price': '\$145.20',
      'change': '-0.95%',
      'isPositive': false,
      'icon': Icons.flash_on,
      'color': Colors.purple,
    },
    {
      'name': 'BNB',
      'symbol': 'BNB',
      'price': '\$580.10',
      'change': '+0.54%',
      'isPositive': true,
      'icon': Icons.token,
      'color': Colors.amber,
    },
    {
      'name': 'Ripple',
      'symbol': 'XRP',
      'price': '\$0.58',
      'change': '-1.20%',
      'isPositive': false,
      'icon': Icons.waves,
      'color': Colors.cyan,
    },
    {
      'name': 'Cardano',
      'symbol': 'ADA',
      'price': '\$0.39',
      'change': '+3.12%',
      'isPositive': true,
      'icon': Icons.auto_awesome,
      'color': Colors.indigoAccent,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.radar, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('CryptoRadar', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شريط البحث
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن عملة رقمية...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // عنوان القائمة
            const Text(
              'الأسواق المباشرة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // قائمة العملات الرقمية
            Expanded(
              child: ListView.builder(
                itemCount: cryptoData.length,
                itemBuilder: (context, index) {
                  final coin = cryptoData[index];
                  return Card(
                    color: const Color(0xFF1E293B),
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (coin['color'] as Color).withOpacity(0.2),
                        child: Icon(coin['icon'], color: coin['color']),
                      ),
                      title: Text(
                        coin['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        coin['symbol'],
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            coin['price'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: coin['isPositive']
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              coin['change'],
                              style: TextStyle(
                                color: coin['isPositive'] ? Colors.green : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
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
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'الأسواق',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'المحفظة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
