import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ip.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class CriarForumPage extends StatefulWidget {
  const CriarForumPage({Key? key}) : super(key: key);

  @override
  _CriarForumPageState createState() => _CriarForumPageState();
}

class _CriarForumPageState extends State<CriarForumPage> {
  final TextEditingController _nomeForumController = TextEditingController();
  String? _selectedArea;
  String? _token;
  String? _idUtilizador;
  String? _idCentro;
  List<dynamic> areas = [];
  bool isLoading = true;

  bool _isLoading = true;

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

    final response = await http.get(
      Uri.parse('$baseUrl/user/profile'),
      headers: {'x-auth-token': _token!},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _idUtilizador = data['ID_FUNCIONARIO'].toString();
        _idCentro = data['ID_CENTRO'].toString();
        isLoading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao obter dados do utilizador')));
    }
  }

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchAreas() async {
    final response = await http.get(Uri.parse('$baseUrl/area/list'));
    if (response.statusCode == 200) {
      setState(() {
        areas = json.decode(response.body);
        if (areas.isNotEmpty) {
          _selectedArea = areas[0]['ID_AREA'].toString();
        }
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erro ao obter áreas')));
    }
  }

  Future<void> _criarForum() async {
    final nomeForum = _nomeForumController.text.trim();
    if (nomeForum.isEmpty || _selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, preencha todos os campos')));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forum/create'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': _token!,
        },
        body: json.encode({
          'ID_CENTRO': _idCentro,
          'ID_AREA': _selectedArea,
          'ID_CRIADOR': _idUtilizador,
          'NOME_FORUM': nomeForum,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fórum criado com sucesso')));
        Navigator.of(context).pop(true);
      } else {
        print('Erro ao criar fórum: ${response.statusCode} - ${response.body}');
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Erro ao criar fórum')));
      }
    } catch (error) {
      print('Erro ao criar fórum: $error');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erro ao criar fórum')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Fórum'),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nome do Fórum:',
                    style: TextStyle(fontSize: 16),
                  ),
                  TextField(
                    controller: _nomeForumController,
                    decoration: const InputDecoration(
                      hintText: 'Digite o nome do fórum',
                    ),
                  ),
                  const SizedBox(height: 20),
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
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _criarForum,
                      child: const Text('Criar Fórum'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}