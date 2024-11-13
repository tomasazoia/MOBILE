import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'ip.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'editar_perfil.dart';
import 'escolher_eventos.dart';
import 'listar_forums.dart';
import 'escolher_estabelecimentos.dart';
import 'drawer/informacoes_avisos.dart';
import 'drawer/calendario.dart';
import '../welcome_page.dart';
import 'drawer/reset_pass.dart';
import 'notificacoes.dart';
import 'detalhes_eventos.dart';

class ProfilePage extends StatefulWidget {
  //final int idUser;

  //ProfilePage({required this.idUser});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  dynamic user;
  bool isLoading = true;
  String erro = '';
  String? _token;
  String? _idUtilizador;
  List<Map<String, dynamic>> _centros = [];
  bool _isLoading = true;
  int currentPageIndex = 0;
  int _selectedIndex = 4;
  List<Map<String, dynamic>> _eventosCriados = [];
  List<Map<String, dynamic>> _eventosInscritos = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _checkConnectivityAndInitData();
    await _loadEventosCriados();
    await _loadEventosInscritos();
    await _fetchAreas();
    await _fetchSubareas();
  }

  //variáveis para controlo das preferencias selecionadas
  Set<int> _selectedAreas = {};
  Set<int> _selectedSubareas = {};

  Future<void> _checkConnectivityAndInitData() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você está offline. Por favor, conecte-se à internet.'),
        ),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    await _initData();
  }

  Future<void> _initData() async {
    await _fetchTokenAndProfile();
    if (_idUtilizador != null) {
      await _fetchUserDetails();
      await _fetchCentros();
      await _fetchUserPreferences();
    } else {
      setState(() {
        erro = 'Erro ao obter ID do utilizador';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchAreas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/area/list'));

      if (response.statusCode == 200) {
        final List<dynamic> areasJson = jsonDecode(response.body);
        setState(() {
          _areas = areasJson.map((area) {
            return {'ID_AREA': area['ID_AREA'], 'NOME_AREA': area['NOME_AREA']};
          }).toList();
        });
      } else {
        throw Exception(
            'Erro ao buscar áreas. Status code: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar áreas: $e')),
      );
    }
  }

  Future<void> _fetchSubareas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/subarea/list'));

      if (response.statusCode == 200) {
        final List<dynamic> subareasJson = jsonDecode(response.body);
        setState(() {
          _subareas = subareasJson.map((subarea) {
            return {
              'ID_SUB_AREA': subarea['ID_SUB_AREA'],
              'NOME_SUBAREA': subarea['NOME_SUBAREA']
            };
          }).toList();
        });
      } else {
        throw Exception(
            'Erro ao buscar subáreas. Status code: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar subáreas: $e')),
      );
    }
  }

  //função para guardar as preferências selecionadas
  Future<void> _fetchUserPreferences() async {
    final response = await http.get(
      Uri.parse('$baseUrl/userpreferences/list/profile/$_idUtilizador'),
      headers: {'x-auth-token': _token!},
    );

    if (response.statusCode == 200) {
      final List<dynamic> preferenciasJson = jsonDecode(response.body);
      setState(() {
        _selectedAreas = preferenciasJson
            .where((p) => p['ID_AREA'] != null)
            .map<int>((p) => p['ID_AREA'] as int)
            .toSet();
        _selectedSubareas = preferenciasJson
            .where((p) => p['ID_SUBAREA'] != null)
            .map<int>((p) => p['ID_SUBAREA'] as int)
            .toSet();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar preferências.')),
      );
    }
  }

  Future<void> _savePreferences() async {
    final updatedPreferences = {
      'areas': _selectedAreas.toList(),
      'subAreas': _selectedSubareas.toList()
    };

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/userpreferences/update/user/$_idUtilizador'),
        headers: {
          'x-auth-token': _token!,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updatedPreferences),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preferências atualizadas com sucesso!')),
        );
      } else {
        throw Exception('Erro ao atualizar preferências.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar preferências: $e')),
      );
    }
  }

  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _subareas = [];

  Future<void> _fetchTokenAndProfile() async {
    _token = await _getAuthToken();
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Token de autenticação não encontrado')));
      return;
    }

    final response = await http.get(
      Uri.parse('$baseUrl/user/profile'),
      headers: {
        'x-auth-token': _token!,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        user = data;
        _idUtilizador = data['ID_FUNCIONARIO'].toString();
        print('ID_FUNCIONARIO: $_idUtilizador');
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao obter dados do utilizador')));
    }
  }

  Future<void> _loadEventosInscritos() async {
    final url =
        '$baseUrl/participantesevento/funcionario/$_idUtilizador/eventos';
    final token = await _getAuthToken();

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'x-auth-token': token!},
      );

      print('Resposta eventos inscritos: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> eventosJson = jsonDecode(response.body);

        setState(() {
          _eventosInscritos = eventosJson.map((evento) {
            final eventoDetails = evento['evento'];
            return {
              'ID_EVENTO': eventoDetails['ID_EVENTO'],
              'NOME_EVENTO': eventoDetails['NOME_EVENTO'],
              'DATA_EVENTO': eventoDetails['DATA_EVENTO'],
            };
          }).toList();
        });
      } else {
        throw Exception('Erro ao obter os eventos inscritos pelo utilizador');
      }
    } catch (e) {
      print('Erro ao carregar eventos inscritos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao obter os eventos inscritos: $e')),
      );
    }
  }

  Future<void> _loadEventosCriados() async {
    if (_idUtilizador == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID do utilizador não está disponível.')),
      );
      return;
    }

    final url = '$baseUrl/evento/criador/eventos/$_idUtilizador';
    final token = await _getAuthToken();

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'x-auth-token': token!},
      );

      print('Resposta eventos criados: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> eventosJson = jsonDecode(response.body);

        setState(() {
          _eventosCriados = eventosJson.map((evento) {
            return {
              'ID_EVENTO': evento['ID_EVENTO'],
              'NOME_EVENTO': evento['NOME_EVENTO'],
              'DATA_EVENTO': evento['DATA_EVENTO'],
            };
          }).toList();
        });
      } else {
        throw Exception(
            'Erro ao obter os eventos criados pelo utilizador. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao carregar eventos criados: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao obter os eventos criados: $e')),
      );
    }
  }

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchUserDetails() async {
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _fetchCentros() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/centro/list'));

      if (response.statusCode == 200) {
        final List<dynamic> centrosJson = jsonDecode(response.body);
        setState(() {
          _centros = centrosJson.map((centro) {
            return {
              'ID_CENTRO': centro['ID_CENTRO'],
              'NOME_CENTRO': centro['NOME_CENTRO']
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        throw Exception(
            'Erro ao buscar centros. Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar centros: $e')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Terminar sessão'),
          content: const Text('Tem a certeza que deseja terminar sessão?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Continuar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => WelcomePage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _navigateToEditarPerfil() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditarPerfil()),
    );

    if (result == true) {
      _fetchTokenAndProfile();
      _fetchUserDetails();
      _fetchCentros();
      setState(() {});
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Data Não Disponível';
    }

    try {
      DateTime dateTime = DateTime.parse(dateString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      print('Erro ao analisar a data: $e');
      return 'Data Inválida';
    }
  }

  String _getCentroName(int idCentro) {
    for (var centro in _centros) {
      if (centro['ID_CENTRO'] == idCentro) {
        return centro['NOME_CENTRO'];
      }
    }
    return 'Centro não encontrado';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Meu Perfil'),
          backgroundColor: Colors.blue,
        ),
        drawer: Drawer(
          child: Container(),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (erro.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Meu Perfil'),
          backgroundColor: Colors.blue,
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              SizedBox(
                height: 100.0,
                child: DrawerHeader(
                  margin: const EdgeInsets.all(0),
                  padding: const EdgeInsets.all(0),
                  decoration: const BoxDecoration(
                    color: Color.fromRGBO(33, 150, 243, 1),
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/logo-softinsa.png',
                      height: kToolbarHeight,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text('Terminar Sessão'),
                onTap: () => _logout(context),
              ),
            ],
          ),
        ),
        body: Center(
          child: Text(erro),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Meu Perfil'),
          backgroundColor: Colors.blue,
        ),
        body: const Center(
          child: Text('Erro ao carregar os dados do utilizador.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        backgroundColor: Colors.blue,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            SizedBox(
              height: 100.0,
              child: DrawerHeader(
                margin: const EdgeInsets.all(0),
                padding: const EdgeInsets.all(0),
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(33, 150, 243, 1),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/logo-softinsa.png',
                    height: kToolbarHeight,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Informações/Avisos'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const InformacoesAvisosPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Calendário de Eventos'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CalendarPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Redefinir Senha'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ResetPassPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('Terminar Sessão'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            Text(
              '@${user!['user_name']}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${user!['user_mail']}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'NIF: ${user!['NIF']}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Morada: ${user!['MORADA']}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Número de Telemóvel: ${user!['NTELEMOVEL']}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Data de Início: ${_formatDate(user!['DATAINICIO'])}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Centro: ${_getCentroName(user!['ID_CENTRO'])}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToEditarPerfil,
              child: const Text('Editar Perfil'),
            ),
            const SizedBox(height: 20),
            Text(
              'Eventos Inscritos:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _eventosInscritos.isEmpty
                ? const Text('Nenhum evento encontrado.')
                : Column(
                    children: _eventosInscritos.map((evento) {
                      return ListTile(
                        title: Text(evento['NOME_EVENTO'].toString()),
                        subtitle: Text(
                            'Data: ${_formatDate(evento['DATA_EVENTO'] ?? 'Data Não Disponível')}\n'),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 20),
// Eventos Criados
            Text(
              'Eventos Criados:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            _eventosCriados.isEmpty
                ? const Text('Nenhum evento encontrado.')
                : Column(
                    children: _eventosCriados.map((evento) {
                      return ListTile(
                        title: Text(evento['NOME_EVENTO']),
                        subtitle: Text(
                          'Data: ${_formatDate(evento['DATA_EVENTO'])}\n',
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetalhesEvento(
                                idEvento: evento['ID_EVENTO'],
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
            // Preferências do Utilizador
            const SizedBox(height: 20),
            const Text(
              'As minhas preferências:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecione as Áreas:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: _areas.map((area) {
                      return CheckboxListTile(
                        title: Text(area['NOME_AREA']),
                        value: _selectedAreas.contains(area['ID_AREA']),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedAreas.add(area['ID_AREA']);
                            } else {
                              _selectedAreas.remove(area['ID_AREA']);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Selecione as Subáreas:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: _subareas.map((subarea) {
                      return CheckboxListTile(
                        title: Text(subarea['NOME_SUBAREA']),
                        value:
                            _selectedSubareas.contains(subarea['ID_SUB_AREA']),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedSubareas.add(subarea['ID_SUB_AREA']);
                            } else {
                              _selectedSubareas.remove(subarea['ID_SUB_AREA']);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savePreferences,
              child: const Text('Guardar Preferências'),
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
            icon: Icon(Icons.account_box, color: Colors.deepPurple),
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
          if (index == _selectedIndex) return;

          Widget page;
          Offset beginOffset;

          if (index > _selectedIndex) {
            beginOffset = const Offset(1.0, 0.0);
          } else {
            beginOffset = const Offset(-1.0, 0.0);
          }

          switch (index) {
            case 0:
              page = EventosPage();
              break;
            case 1:
              page = const ForumPage();
              break;
            case 2:
              page = NotificationsPage();
              break;
            case 3:
              page = LocaisPage();
              break;
            /*case 4:
              page = ProfilePage(
                  idUser: widget.idUser);
              break;*/
            default:
              return;
          }

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
        },
      ),
    );
  }
}
