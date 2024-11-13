import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'ip.dart';
import 'listar_eventos.dart';
import 'listar_forums.dart';
import 'escolher_estabelecimentos.dart';
import 'meu_perfil.dart';
import 'notificacoes.dart';

class EventosPage extends StatefulWidget {
  const EventosPage({super.key});

  @override
  State<EventosPage> createState() => _EventosPageState();
}

class _EventosPageState extends State<EventosPage> {
  List<dynamic> areas = [];
  bool _isLoading = false;
  int currentPageIndex = 0;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchAreas();
  }

  Future<void> _fetchAreas() async {
    setState(() {
      _isLoading = true;
    });

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Você está offline. Por favor, conecte-se à internet.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl/area/list'));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            areas = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar áreas: $error')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildAreaList() {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView.builder(
            itemCount:
                areas.length + 1, // +1 para adicionar o botão "Todas as Áreas"
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // Cor do botão
                      foregroundColor: Colors.white, // Cor do texto
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EventosAreaState(
                              idArea:
                                  -1), // Passa -1 como idArea para representar todas as áreas
                        ),
                      );
                    },
                    child: const Text(
                      'Todas as Áreas',
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
                );
              } else {
                final area = areas[index -
                    1]; // Subtraí 1 por causa do botão extra no início da lista
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue, // Cor do botão
                      foregroundColor: Colors.white, // Cor do texto
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EventosAreaState(idArea: area['ID_AREA']),
                        ),
                      );
                    },
                    child: Text(
                      area['NOME_AREA'],
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                );
              }
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos por área'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
      ),
      body: _buildAreaList(),
      bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.event_available, color: Colors.deepPurple),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forum),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_box),
              label: '',
            ),
          ],
          currentIndex: _selectedIndex,
          backgroundColor: Colors.blue,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: (int index) {
            setState(() {
              _selectedIndex = index;
            });

            Widget page;
            switch (index) {
              /*case 0:
              page = EventosPage();
              break;*/
              case 1:
                page = const ForumPage();
                break;
              case 2:
                page = NotificationsPage();
                break;
              case 3:
                page = LocaisPage();
                break;
              case 4:
                page = ProfilePage();
                break;
              default:
                return;
            }

            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => page,
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  const begin =
                      Offset(1.0, 0.0); // Desliza da direita para a esquerda
                  const end = Offset.zero;
                  const curve = Curves.ease;

                  var tween = Tween(begin: begin, end: end)
                      .chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);

                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
              ),
            ).then((_) {
              setState(() {
                _selectedIndex = 0;
              });
            });
          }),
    );
  }
}