import 'dart:convert';
import 'package:flutter/material.dart';
import 'escolher_eventos.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ip.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'criar_forum.dart';
import 'detalhes_forums.dart';
import 'escolher_estabelecimentos.dart';
import 'meu_perfil.dart';
import 'notificacoes.dart';

class ForumPage extends StatefulWidget {
  const ForumPage({Key? key}) : super(key: key);

  @override
  _ForumPageState createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  String? _selectedArea;
  String? _token;
  List<dynamic> areas = [];
  List<dynamic> forums = [];
  bool isLoading = true;
  String erro = '';
  int currentPageIndex = 0;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndInitData();
  }

  Future<void> _checkConnectivityAndInitData() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você está offline. Por favor, conecte-se à internet.'),
        ),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    await _initData();
  }

  Future<void> _initData() async {
    await _fetchTokenAndProfile();
    await _fetchAreas();
  }

  Future<void> _fetchTokenAndProfile() async {
    _token = await _getAuthToken();
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Token de autenticação não encontrado')));
      return;
    }
  }

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchAreas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/area/list'));
      if (response.statusCode == 200) {
        setState(() {
          areas = json.decode(response.body);
          if (areas.isNotEmpty) {
            _selectedArea = areas[0]['ID_AREA'].toString();
            _fetchForums(_selectedArea!);
          }
        });
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Erro ao obter áreas')));
      }
    } catch (e) {
      print('Erro ao carregar áreas: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar áreas')));
    }
  }

  Future<void> _fetchForums(String idArea) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/forum/area/$idArea'));
      if (response.statusCode == 200) {
        final forumsData = json.decode(response.body);


        for (var forum in forumsData) {
          final creatorResponse = await http.get(
            Uri.parse('$baseUrl/user/${forum['ID_CRIADOR']}'),
            headers: {'x-auth-token': _token!},
          );

          if (creatorResponse.statusCode == 200) {
            final creatorData = json.decode(creatorResponse.body);
            forum['nome_criador'] = creatorData['user_name'];
          } else {
            forum['nome_criador'] = 'Nome não disponível';
          }
        }

        forumsData.sort(
            (a, b) => (a['ID_FORUM'] as int).compareTo(b['ID_FORUM'] as int));

        setState(() {
          forums = forumsData;
          isLoading = false;
        });
      } else {
        setState(() {
          forums = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar fóruns: $e');
      setState(() {
        forums = [];
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar fóruns')));
    }
  }

  Future<String> _fetchNomeCriadorForum(String idCriador) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$idCriador'),
        headers: {'x-auth-token': _token!},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['user_name'];
      } else {
        throw Exception('Erro ao obter nome do criador');
      }
    } catch (error) {
      print('Erro ao obter nome do criador: $error');
      return 'Nome não disponível';
    }
  }

  void _onForumDeleted() {
    if (_selectedArea != null) {
      _fetchForums(_selectedArea!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fóruns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (context) => const CriarForumPage(),
                ),
              )
                  .then((result) {
                if (result != null && result is bool && result) {
                  _fetchForums(_selectedArea!);
                }
              });
            },
          ),
        ],
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Área:',
                    style: TextStyle(fontSize: 16),
                  ),
                  DropdownButton<String>(
                    value: _selectedArea,
                    items: areas.map<DropdownMenuItem<String>>((area) {
                      return DropdownMenuItem<String>(
                        value: area['ID_AREA'].toString(),
                        child: Text(area['NOME_AREA']),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedArea = newValue;
                        _fetchForums(_selectedArea!);
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: forums.isEmpty
                        ? const Center(
                            child: Text(
                                'Ainda não há fóruns criados para esta área.'),
                          )
                        : ListView.builder(
                            itemCount: forums.length,
                            itemBuilder: (context, index) {
                              final idCriador =
                                  forums[index]['ID_CRIADOR'].toString();
                              return FutureBuilder<String>(
                                future: _fetchNomeCriadorForum(idCriador),
                                builder: (context, snapshot) {
                                  String nomeCriador = 'Nome não disponível';
                                  if (snapshot.connectionState ==
                                      ConnectionState.done) {
                                    if (snapshot.hasData) {
                                      nomeCriador = snapshot.data!;
                                    } else {
                                      nomeCriador = 'Erro ao carregar nome';
                                    }
                                  }
                                  return Card(
                                    child: ListTile(
                                      title: Text(forums[index]['NOME_FORUM']),
                                      subtitle:
                                          Text('Criado por: @$nomeCriador'),
                                      onTap: () {
                                        Navigator.of(context)
                                            .push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                DetalhesForumPage(
                                              forumId: forums[index]['ID_FORUM']
                                                  .toString(),
                                            ),
                                          ),
                                        )
                                            .then((result) {
                                          if (result != null &&
                                              result is bool &&
                                              result) {
                                            _onForumDeleted();
                                          }
                                        });
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.event_available),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.forum,
                color: Colors.deepPurple
              ),
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
          backgroundColor: Colors.blue,
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: (int index) {
            if (index == _selectedIndex)
              return; // Evita navegação desnecessária.

            Widget page;
            Offset beginOffset;

            if (index > _selectedIndex) {
              // Desloca para a direita
              beginOffset = const Offset(1.0, 0.0);
            } else {
              // Desloca para a esquerda
              beginOffset = const Offset(-1.0, 0.0);
            }

            switch (index) {
              case 0:
                page = EventosPage();
                break;
              /*case 1:
                page = const ForumPage();
                break;*/
              case 2:
                page = NotificationsPage();
                break;
              case 3:
                page = LocaisPage();
                break;
              case 4:
                //page = ProfilePage(idUser: 0);
                page = ProfilePage();
                break;
              default:
                return;
            }

            // Usar o mesmo Navigator.push para todas as direções
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => page,
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  const end = Offset.zero;
                  const curve = Curves.ease;

                  var tween = Tween(begin: beginOffset, end: end)
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
                _selectedIndex = index;
              });
            });
          }
      ),
    );
  }
}