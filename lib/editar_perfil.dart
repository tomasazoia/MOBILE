import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'ip.dart';

class EditarPerfil extends StatefulWidget {
  const EditarPerfil({Key? key}) : super(key: key);

  @override
  State<EditarPerfil> createState() => _EditarPerfilState();
}

class _EditarPerfilState extends State<EditarPerfil> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _userMailController = TextEditingController();
  final TextEditingController _nifController = TextEditingController();
  final TextEditingController _moradaController = TextEditingController();
  final TextEditingController _nTelemovelController = TextEditingController();

  String? _token;
  String? _idUtilizador;
  String? _errorMessage;
  dynamic _userData;

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
    _populateControllers();
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
      headers: {
        'x-auth-token': _token!,
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _idUtilizador = data['ID_FUNCIONARIO'].toString();
        _userData = data;
      });
      _populateControllers();
    } else {
      setState(() {
        _errorMessage = 'Erro ao obter dados do utilizador';
      });
    }
  }

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  void _populateControllers() {
    if (_userData != null) {
      _userNameController.text = _userData['user_name'];
      _userMailController.text = _userData['user_mail'];
      _nifController.text = _userData['NIF'].toString();
      _moradaController.text = _userData['MORADA'];
      _nTelemovelController.text = _userData['NTELEMOVEL'];
    }
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> formData = {
        'user_name': _userNameController.text,
        'user_mail': _userMailController.text,
        'NIF': _nifController.text,
        'MORADA': _moradaController.text,
        'NTELEMOVEL': _nTelemovelController.text,
      };

      try {
        final response = await http.put(
          Uri.parse('$baseUrl/user/profileup'),
          headers: {
            'Content-Type': 'application/json',
            'x-auth-token': _token!,
          },
          body: jsonEncode(formData),
        );

        if (mounted) {
          if (response.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Perfil atualizado com sucesso'),
            ));
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Erro ao atualizar perfil'),
            ));
          }
        }
      } catch (e) {
        print('Erro ao enviar requisição: $e');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erro ao conectar ao servidor'),
        ));
      }
    }
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _userMailController.dispose();
    _nifController.dispose();
    _moradaController.dispose();
    _nTelemovelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.blue,
      ),
      body: _idUtilizador != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _userNameController,
                      decoration: const InputDecoration(
                          labelText: 'Nome do Utilizador'),
                      enabled: true, 
                    ),
                    TextFormField(
                      controller: _userMailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      enabled: true, 
                    ),
                    TextFormField(
                      controller: _nifController,
                      decoration: const InputDecoration(labelText: 'NIF'),
                      enabled: true, 
                    ),
                    TextFormField(
                      controller: _moradaController,
                      decoration: const InputDecoration(labelText: 'Morada'),
                      enabled: true, 
                    ),
                    TextFormField(
                      controller: _nTelemovelController,
                      decoration: const InputDecoration(
                          labelText: 'Número de Telemóvel'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _handleSubmit,
                      child: const Text('Guardar Alterações'),
                    ),
                  ],
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
