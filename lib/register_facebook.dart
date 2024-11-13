import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'escolher_eventos.dart';
import 'ip.dart';

class RegisterFacebookPage extends StatefulWidget {
  @override
  _RegisterFacebookPageState createState() => _RegisterFacebookPageState();
}

class _RegisterFacebookPageState extends State<RegisterFacebookPage> {
  final _formKey = GlobalKey<FormState>();

  String _nif = '';
  String _morada = '';
  String _telefone = '';
  String _centro = '';

  List<Map<String, dynamic>> _centros = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCentros();
  }

  Future<void> _fetchCentros() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/centro/list'));
      if (response.statusCode == 200) {
        setState(() {
          _centros = List<Map<String, dynamic>>.from(jsonDecode(response.body));
        });
      } else {
        setState(() {
          _error = 'Erro ao buscar centros';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erro ao buscar centros: $e';
      });
    }
  }

  Future<void> _registerWithFacebook() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showError('Você está offline. Por favor, conecte-se à internet.');
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      try {
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final String authToken = prefs.getString('auth_token') ?? '';

        if (authToken.isEmpty) {
          _showError('Token de autenticação não encontrado.');
          return;
        }

        bool success = await _sendDataToBackend(authToken);

        if (success) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => EventosPage()),
          );
        }
      } catch (e) {
        print('Erro ao registar com Facebook: $e');
        _showError('Erro ao registar com Facebook. Tente novamente.');
      }
    }
  }

  Future<bool> _sendDataToBackend(String authToken) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/profileup'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          'x-auth-token': authToken,
        },
        body: jsonEncode(<String, String>{
          'NIF': _nif,
          'MORADA': _morada,
          'NTELEMOVEL': _telefone,
        }),
      );

      print('Status Code Profile: ${response.statusCode}');
      print('Response Body Profile: ${response.body}');

      if (response.statusCode == 200) {
        final responseCentro = await http.put(
          Uri.parse('$baseUrl/user/updateCentro'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            'x-auth-token': authToken,
          },
          body: jsonEncode(<String, String>{
            'ID_CENTRO': _centro,
          }),
        );

        print('Status Code Centro: ${responseCentro.statusCode}');
        print('Response Body Centro: ${responseCentro.body}');

        if (responseCentro.statusCode == 200) {
          Fluttertoast.showToast(
            msg: 'Registo bem-sucedido!',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
          );
          return true; // Sucesso
        } else {
          _showError('Erro ao atualizar o centro: ${responseCentro.body}');
          return false; // Falha na atualização do centro
        }
      } else {
        _showError('Erro a registar dados do perfil: ${response.body}');
        return false; // Falha no registo de dados do perfil
      }
    } catch (e) {
      _showError('Erro ao enviar dados: $e');
      return false; // Erro geral
    }
  }

  void _showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registar com Facebook'),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'Complete seu registo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (_error != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                padding: const EdgeInsets.all(16.0),
                color: Colors.redAccent,
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  children: <Widget>[
                    _buildTextField(
                      'NIF',
                      'Digite seu NIF',
                      (value) => _nif = value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    _buildTextField(
                      'Morada',
                      'Digite sua morada',
                      (value) => _morada = value,
                    ),
                    _buildTextField(
                      'Telefone',
                      'Digite seu telefone',
                      (value) => _telefone = value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    _buildDropdownButton(),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _registerWithFacebook,
                      child: const Text('Prosseguir com Registo'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    Function(String) onChanged, {
    List<TextInputFormatter>? inputFormatters,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Por favor, insira seu $label';
          }
          return null;
        },
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildDropdownButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: 'Centro',
          border: OutlineInputBorder(),
        ),
        items: _centros.map((centro) {
          return DropdownMenuItem<String>(
            value: centro['ID_CENTRO'].toString(),
            child: Text(centro['NOME_CENTRO']),
          );
        }).toList(),
        onChanged: (value) => _centro = value ?? '',
        validator: (value) => value == null || value.isEmpty
            ? 'Por favor, selecione um centro'
            : null,
      ),
    );
  }
}