import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ip.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'escolher_eventos.dart';
import 'listar_forums.dart';
import 'escolher_estabelecimentos.dart';
import 'meu_perfil.dart';

class NotificationModel {
  final int id;
  final String message;
  final bool read;

  NotificationModel({
    required this.id,
    required this.message,
    required this.read,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['ID_NOTIFICACAO'],
      message: json['MENSAGEM'],
      read: json['LIDA'],
    );
  }
}

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<NotificationModel>> _notifications;
  String? _token;
  String? _userId;
  bool _isLoading = true;
  String? _error;

  int currentPageIndex = 0;
  int _selectedIndex = 2;

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
        _isLoading = false;
      });
      return;
    }

    await _fetchTokenAndProfile();
    if (_userId != null) {
      setState(() {
        _notifications = _fetchNotifications();
        _isLoading = false; 
      });
    } else {
      setState(() {
        _error = 'Erro ao obter ID do utilizador';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTokenAndProfile() async {
    _token = await _getAuthToken();
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Token de autenticação não encontrado')));
      setState(() {
        _isLoading = false; // Atualiza o estado se o token não for encontrado
      });
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
        _userId = data['ID_FUNCIONARIO'].toString();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao obter dados do utilizador')));
    }
  }

  Future<List<NotificationModel>> _fetchNotifications() async {
    if (_token == null || _userId == null) {
      throw Exception('Token de autenticação ou ID do usuário não encontrados');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/notificacoes/user/$_userId'),
      headers: {
        'x-auth-token': _token!,
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => NotificationModel.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar notificações');
    }
  }

  Future<void> _markAsRead(int id) async {
    if (_token == null) return;

    final response = await http.put(
      Uri.parse('$baseUrl/notificacoes/read/$id'),
      headers: {
        'x-auth-token': _token!,
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        _notifications = _fetchNotifications();
      });
    } else {
      throw Exception('Falha ao marcar notificação como lida');
    }
  }

  Future<void> _deleteNotification(int id) async {
    if (_token == null) return;

    final response = await http.delete(
      Uri.parse('$baseUrl/notificacoes/delete/$id'),
      headers: {
        'x-auth-token': _token!,
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        _notifications = _fetchNotifications();
      });
    } else {
      throw Exception('Falha ao apagar notificação');
    }
  }

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Notificações'),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Notificações'),
        ),
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Notificações'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<NotificationModel>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Nenhuma notificação disponível.'));
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                title: Text(notification.message),
                tileColor: notification.read ? Colors.grey[200] : Colors.white,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!notification.read)
                      IconButton(
                        icon: Icon(Icons.mark_chat_read_rounded),
                        onPressed: () => _markAsRead(notification.id),
                      ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteNotification(notification.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
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
              icon: Icon(Icons.notifications, color: Colors.deepPurple),
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
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black,
          currentIndex: _selectedIndex,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          onTap: (int index) {
            if (index == _selectedIndex)
              return; // Evita navegação desnecessária.

            Widget page;
            Offset beginOffset;

            // Define a direção da animação (direita ou esquerda) com base no índice atual
            if (index > _selectedIndex) {
              // Desloca para a direita
              beginOffset = const Offset(1.0, 0.0);
            } else {
              // Desloca para a esquerda
              beginOffset = const Offset(-1.0, 0.0);
            }

            // Definir qual página carregar com base no índice
            switch (index) {
              case 0:
                page = EventosPage();
                break;
              case 1:
                page = const ForumPage(); // Página de Fóruns
                break;
              /*case 2:
                page = CreateEventPage();
                break;*/
              case 3:
                page = LocaisPage();
                break;
              case 4:
                page = ProfilePage();
                break;
              default:
                return;
            }

            // Transição para a página correspondente usando animação de deslizamento
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => page,
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  const end = Offset.zero;
                  const curve = Curves.ease;

                  // Animação de deslizamento da página
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
              // Atualizar o índice selecionado após a navegação
              setState(() {
                _selectedIndex = index;
              });
            });
          }),
    );
  }
}