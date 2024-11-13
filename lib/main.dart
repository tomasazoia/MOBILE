import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'welcome_page.dart';
import 'criar_conta.dart';
import 'escolher_eventos.dart';
import 'criar_eventos.dart';
import 'notificacoes.dart';
import 'conexao_internet.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      title: 'Bem-vindo...',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Stack(
        children: [
          FutureBuilder(
            future: _checkLoginStatus(),
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else {
                return WelcomePage();
              }
            },
          ),
          ConnectivityStatus(),
        ],
      ),
      routes: {
        '/login': (context) => LoginPage(),
        '/contaCreate': (context) => ContaCreate(),
        '/eventosPage': (context) => EventosPage(),
        '/definicoes': (context) => NotificationsPage(), //definicoes ???
        '/criarEvento': (context) => CreateEventPage(),
      },
    );
  }

  Future<bool> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');
    return token != null;
  }
}
