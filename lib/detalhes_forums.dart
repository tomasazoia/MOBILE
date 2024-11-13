import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'ip.dart';

class DetalhesForumPage extends StatefulWidget {
  final String forumId;

  const DetalhesForumPage({Key? key, required this.forumId}) : super(key: key);

  @override
  _DetalhesForumPageState createState() => _DetalhesForumPageState();
}

class _DetalhesForumPageState extends State<DetalhesForumPage> {
  String? _token;
  String? _idUtilizador;
  String erro = '';
  bool isLoading = true;
  List<dynamic> messages = [];
  Map<String, dynamic>? _forumDetails = {};
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTokenAndMessages();
  }

  Future<void> _fetchTokenAndMessages() async {
    _token = await _getAuthToken();
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token de autenticação não encontrado')),
      );
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
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao obter dados do utilizador')),
      );
    }
    await _fetchForumDetails();
    await _fetchMessages();
  }

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchForumDetails() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/forum/get/${widget.forumId}'),
        headers: {
          'x-auth-token': _token!,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _forumDetails = data;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar detalhes do fórum')),
        );
      }
    } catch (e) {
      print('Erro ao carregar detalhes do fórum: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar detalhes do fórum')),
      );
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comentarios_forum/list/${widget.forumId}'),
      );
      if (response.statusCode == 200) {
        final messagesData = json.decode(response.body);

        for (var message in messagesData) {
          final creatorResponse = await http.get(
            Uri.parse('$baseUrl/user/${message['ID_FUNCIONARIO']}'),
            headers: {'x-auth-token': _token!},
          );

          if (creatorResponse.statusCode == 200) {
            final creatorData = json.decode(creatorResponse.body);
            message['username'] = creatorData['user_name'];
          } else {
            message['username'] = 'Nome não disponível';
          }
        }

        setState(() {
          messages = messagesData;
          isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar mensagens')),
        );
      }
    } catch (e) {
      print('Erro ao carregar mensagens: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar mensagens')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    // Verifica se a mensagem está vazia
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, escreva uma mensagem')),
      );
      return;
    }

    // Verifica se o token de autenticação está presente
    if (_token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token de autenticação não encontrado')),
      );
      return;
    }

    try {
      // Preparar o corpo do pedido
      final requestBody = {
        'ID_FUNCIONARIO': _idUtilizador,
        'DESCRICAO': message,
        'ID_FORUM': widget.forumId,
        'DATA_COMENTARIO': DateTime.now().toIso8601String(),
      };

      // Enviar o pedido HTTP POST
      final response = await http.post(
        Uri.parse('$baseUrl/comentarios_forum/create'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': _token!,
        },
        body: json.encode(requestBody),
      );

      // Verificar se a mensagem foi enviada com sucesso
      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensagem enviada com sucesso')),
        );

        // Limpar a caixa de texto
        _messageController.clear();

        // Atualizar a lista de mensagens
        _fetchMessages();
      } else {
        // Se houver um erro, mostrar a mensagem correspondente
        final errorResponse = json.decode(response.body);
        print(
            'Erro ao enviar mensagem: ${response.statusCode} - ${errorResponse['message']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Erro ao enviar mensagem: ${errorResponse['message']}'),
          ),
        );
      }
    } catch (error) {
      // Capturar e exibir erros durante o envio da mensagem
      print('Erro ao enviar mensagem: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar mensagem: $error')),
      );
    } finally {
      // Garantir que a caixa de texto é sempre limpa no final
      setState(() {
        _messageController.clear();
      });
    }
  }

  Future<void> _apagarForum() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/forum/delete/${widget.forumId}'),
        headers: {'x-auth-token': _token!},
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao apagar fórum.')),
        );
      }
    } catch (error) {
      print('Erro ao apagar fórum: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao apagar fórum: $error')),
      );
    }
  }

  Future<void> _deleteComentario(int idComentario) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/comentarios_forum/delete/$idComentario'),
        headers: {
          'x-auth-token': _token!,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          messages.removeWhere(
              (comentario) => comentario['ID_COMENTARIO'] == idComentario);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comentário excluído com sucesso.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao excluir comentário.')),
        );
      }
    } catch (error) {
      print('Erro ao excluir comentário: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir comentário: $error')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportTypes() async {
    final response = await http.get(Uri.parse('$baseUrl/reporttopicos/list'));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      // Retorna os tópicos com ID e NOME_TOPICO
      return data
          .map<Map<String, dynamic>>((item) => {
                'ID_TOPICO': item['ID_TOPICO'],
                'NOME_TOPICO': item['NOME_TOPICO'],
              })
          .toList();
    } else {
      throw Exception('Falha ao carregar tópicos');
    }
  }

  void sendReport(BuildContext context, int comentarioId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return FutureBuilder(
          future: fetchReportTypes(), // Função para buscar os tópicos
          builder: (BuildContext context,
              AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return AlertDialog(
                title: const Text("Erro"),
                content: const Text("Erro ao carregar os tópicos de denúncia."),
                actions: <Widget>[
                  TextButton(
                    child: const Text("Fechar"),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            } else if (snapshot.hasData) {
              List<Map<String, dynamic>> reportTypes = snapshot.data!;
              String selectedReportType = reportTypes[0]['NOME_TOPICO'];
              int selectedReportTypeId = reportTypes[0]['ID_TOPICO'];

              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return AlertDialog(
                    title: const Text("Selecione um motivo"),
                    content: DropdownButton<String>(
                      value: selectedReportType,
                      items: reportTypes.map((Map<String, dynamic> value) {
                        return DropdownMenuItem<String>(
                          value: value['NOME_TOPICO'],
                          child: Text(value['NOME_TOPICO']),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedReportType = newValue;
                            selectedReportTypeId = reportTypes.firstWhere(
                                (element) =>
                                    element['NOME_TOPICO'] ==
                                    newValue)['ID_TOPICO'];
                          });
                        }
                      },
                    ),
                    actions: <Widget>[
                      TextButton(
                        child: const Text("Cancelar"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text("Enviar"),
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await createReport(
                              comentarioId, selectedReportTypeId, context);
                        },
                      ),
                    ],
                  );
                },
              );
            } else {
              return const SizedBox();
            }
          },
        );
      },
    );
  }

  Future<void> createReport(
      int comentarioId, int tipoReportId, BuildContext context) async {
    final url = Uri.parse('$baseUrl/reportforums/create');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'ID_COMENTARIO_REPORTADO': comentarioId,
        'ID_TIPO_REPORT': tipoReportId,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report enviado com sucesso')),
      );
    } else {
      final errorMsg =
          json.decode(response.body)['error'] ?? 'Erro ao criar o report';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $errorMsg')),
      );
    }
  }

  Future<void> _partilharForum() async {
    try {
      // Fazer fetch dos centros
      final centroResponse = await http.get(
        Uri.parse('$baseUrl/centro/list'),
        headers: {'x-auth-token': _token!},
      );

      if (centroResponse.statusCode == 200) {
        final List<dynamic> centros = json.decode(centroResponse.body);

        // Mostrar o pop-up para selecionar o centro
        final selectedCentro = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Selecionar Centro'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: centros.map((centro) {
                    return ListTile(
                      title: Text(centro['NOME_CENTRO']),
                      onTap: () {
                        Navigator.of(context)
                            .pop(centro['ID_CENTRO'].toString());
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context)
                        .pop(); // Fechar o diálogo sem selecionar
                  },
                ),
              ],
            );
          },
        );

        // Se um centro foi selecionado
        if (selectedCentro != null) {
          // Fazer fetch dos utilizadores filtrados pelo centro selecionado
          final response = await http.get(
            Uri.parse('$baseUrl/user/list'),
            headers: {'x-auth-token': _token!},
          );

          if (response.statusCode == 200) {
            final List<dynamic> users = json.decode(response.body);

            // Filtrar utilizadores pelo centro selecionado e remover o utilizador logado
            List<dynamic> filteredUsers = users.where((user) {
              return user['ID_CENTRO'] == int.parse(selectedCentro) &&
                  user['ID_FUNCIONARIO'].toString() != _idUtilizador;
            }).toList();

            if (filteredUsers.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Nenhum utilizador disponível para partilhar.'),
                ),
              );
              return;
            }

            // Mostrar o pop-up com a lista de utilizadores filtrados
            final selectedUser = await showDialog<String>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Selecionar Utilizador para Notificar'),
                  content: SingleChildScrollView(
                    child: ListBody(
                      children: filteredUsers.map((user) {
                        return ListTile(
                          title: Text(user['user_name']),
                          onTap: () {
                            Navigator.of(context).pop(user['ID_FUNCIONARIO']
                                .toString()); // Retornar o ID do utilizador selecionado
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Cancelar'),
                      onPressed: () {
                        Navigator.of(context)
                            .pop(); // Fechar o diálogo sem selecionar
                      },
                    ),
                  ],
                );
              },
            );

            // Verifica se um utilizador foi selecionado
            if (selectedUser != null) {
              // Obter o nome do utilizador logado
              final loggedInUserResponse = await http.get(
                Uri.parse('$baseUrl/user/profile'),
                headers: {'x-auth-token': _token!},
              );

              if (loggedInUserResponse.statusCode == 200) {
                final loggedInUser = json.decode(loggedInUserResponse.body);

                // Enviar notificação ao utilizador selecionado
                final notificationResponse = await http.post(
                  Uri.parse('$baseUrl/notificacoes/create'),
                  headers: {
                    'Content-Type': 'application/json',
                    'x-auth-token': _token!,
                  },
                  body: json.encode({
                    'ID_USER':
                        selectedUser, // O ID do utilizador a quem vai a notificação
                    'MENSAGEM':
                        '@${loggedInUser['user_name']} partilhou este fórum: ${_forumDetails?['NOME_FORUM'] ?? 'Fórum sem título'}',
                  }),
                );

                if (notificationResponse.statusCode == 201) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fórum partilhado com sucesso!'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro ao partilhar fórum.'),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Erro ao obter dados do utilizador logado.'),
                  ),
                );
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro ao obter utilizadores.'),
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao obter centros.'),
          ),
        );
      }
    } catch (error) {
      setState(() {
        erro = 'Erro ao partilhar fórum.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_forumDetails?['NOME_FORUM'] ?? 'Título não disponível'),
        actions: [
          if (_forumDetails != null &&
              _forumDetails!['ID_CRIADOR'].toString() == _idUtilizador)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _apagarForum,
              color: const Color.fromARGB(255, 230, 72, 61),
            ),
        ],
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Mensagens',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _partilharForum,
                    child: const Text('Partilhar com colaboradores'),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final comentario = messages[index];
                        return Column(
                          children: [
                            ListTile(
                              title: RichText(
                                text: TextSpan(
                                  children: <TextSpan>[
                                    TextSpan(
                                      text:
                                          '@${comentario['username'] ?? comentario['ID_FUNCIONARIO']}: ',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    TextSpan(
                                      text: comentario['DESCRICAO'],
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (comentario['ID_FUNCIONARIO'].toString() ==
                                      _idUtilizador)
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _deleteComentario(
                                          comentario['ID_COMENTARIO']),
                                    ),
                                  if (comentario['ID_FUNCIONARIO'].toString() !=
                                      _idUtilizador)
                                    IconButton(
                                      icon: const Icon(Icons.report),
                                      color: const Color.fromARGB(255, 230, 72, 61),
                                      onPressed: () => sendReport(context, comentario['ID_COMENTARIO']),
                                    ),
                                ],
                              ),
                            ),
                            const Divider(),
                          ],
                        );
                      },
                    ),
                  ),
                  TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Escreva sua mensagem',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}