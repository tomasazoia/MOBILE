import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'ip.dart';
import 'detalhes_eventos.dart';
import 'main.dart';
import 'criar_eventos.dart';

class EventosAreaState extends StatefulWidget {
  final int idArea;
  const EventosAreaState({super.key, required this.idArea});
  @override
  _EventosAreaState createState() => _EventosAreaState();
}

class _EventosAreaState extends State<EventosAreaState> with RouteAware {
  List<dynamic> eventos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEventos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (mounted) {
      _fetchEventos();
    }
  }

  Future<void> _fetchEventos() async {
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
      final String url = widget.idArea == -1
          ? '$baseUrl/evento/listdisp' // URL para listar todos os eventos
          : '$baseUrl/evento/listarea/${widget.idArea}'; // URL para listar eventos por área

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            eventos = json.decode(response.body);
            eventos.sort((a, b) => a['ID_EVENTO'].compareTo(b['ID_EVENTO']));
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
        SnackBar(content: Text('Erro ao carregar eventos: $error')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(String dateString) {
    DateTime dateTime = DateTime.parse(dateString);
    String formattedDate =
        '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    String formattedTime =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$formattedDate $formattedTime';
  }

    Future<void> _navigateToCreateEventPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateEventPage()),
    );

    if (result == true) {
      _fetchEventos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, false);
        return false;
      },
      child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Colors.blue,
                Color.fromARGB(255, 13, 58, 95),
              ],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text("Eventos"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    await _navigateToCreateEventPage();
                    _fetchEventos();
                  },
                ),
              ],
            ),
            body: _buildEventsList(),
          )),
    );
  }

  Widget _buildEventsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (eventos.isEmpty) {
      return const Center(
        child: Text(
          'Não há eventos disponíveis.',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    } else {
      return ListView.builder(
        itemCount: eventos.length,
        itemBuilder: (context, index) {
          final evento = eventos[index];
          return _buildEventCard(
            context,
            _formatDate(evento['DATA_EVENTO']),
            evento['NOME_EVENTO'],
            evento['foto'],
            'DETALHES',
            evento['ID_EVENTO'],
          );
        },
      );
    }
  }

  String _getFullImageUrl(String imagePath) {
    if (imagePath != null && imagePath.startsWith('http')) {
      return imagePath;
    } else {
      return '$baseUrl/$imagePath';
    }
  }

  Widget _buildEventCard(
    BuildContext context,
    String date,
    String title,
    String imagePath,
    String buttonText,
    int idEvento,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imagePath != null)
            Image.network(
              _getFullImageUrl(imagePath),
              fit: BoxFit.cover,
              loadingBuilder: (BuildContext context, Widget child,
                  ImageChunkEvent? loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            )
          else
            Container(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              date,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => DetalhesEvento(idEvento: idEvento)),
                );
              },
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}