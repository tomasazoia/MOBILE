import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ip.dart';

class InformacoesAvisosPage extends StatefulWidget {
  const InformacoesAvisosPage({super.key});

  @override
  State<InformacoesAvisosPage> createState() => _InformacoesAvisosPageState();
}

class _InformacoesAvisosPageState extends State<InformacoesAvisosPage> {
  List<dynamic> _informacoes = [];
  bool _isLoading = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _fetchInformacoes();
  }

  Future<void> _fetchInformacoes() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/infos/list'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _informacoes = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _erro = 'Erro ao carregar informações.';
          _isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _erro = 'Erro ao carregar informações: $error';
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

  Future<String> _fetchNomeCriador(int idCriador) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/$idCriador'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['user_name'] ?? 'Desconhecido';
      } else {
        return 'Desconhecido';
      }
    } catch (error) {
      return 'Desconhecido';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informações/Avisos'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(child: Text(_erro!))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _informacoes.length,
                  itemBuilder: (context, index) {
                    final info = _informacoes[index];
                    return FutureBuilder<String>(
                      future: _fetchNomeCriador(info['ID_CRIADOR']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else {
                          final nomeCriador = snapshot.data ?? 'Desconhecido';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              title: Text(
                                info['TITULO'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Text(info['DESCRICAO']),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Data: ${_formatDate(info['DATA_CRIACAO'])}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Mensagem de: @$nomeCriador',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}