import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  String _getSaudacao() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 6 && hour < 12) {
      return 'Bom dia!';
    } else if (hour >= 12 && hour < 20) {
      return 'Boa tarde!';
    } else {
      return 'Boa noite!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(),
        flexibleSpace: Align(
          alignment: Alignment.center,
          child: Image.asset('assets/logo-softinsa.png',
              fit: BoxFit.cover, height: kToolbarHeight),
        ),
      ),
      body: Stack(
        children: [
          // Fundo com gradiente
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Colors.blue, Color.fromARGB(255, 14, 2, 73)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    _getSaudacao(),
                    style: const TextStyle(
                      fontSize: 32.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text(
                      'Entrar',
                      style: TextStyle(
                        color: Color.fromARGB(255, 13, 58, 95),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Botão de alteração de linguagem no canto superior direito
          Positioned(
            top: 16.0,
            right: 16.0,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.language, color: Colors.white),
              onSelected: (String value) {
                // Aqui pode implementar a lógica de troca de linguagem
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Língua selecionada: $value')),
                );
              },
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'Português',
                    child: Text('Português'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Inglês',
                    child: Text('Inglês'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'Espanhol',
                    child: Text('Espanhol'),
                  ),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }
}