import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
//import 'package:clipboard/clipboard.dart';
import 'ip.dart';
import 'album_fotos.dart';
import 'editar_evento.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';


class DetalhesEvento extends StatefulWidget {
  final int idEvento;

  DetalhesEvento({required this.idEvento});

  @override
  _DetalhesEventoState createState() => _DetalhesEventoState();
}

class _DetalhesEventoState extends State<DetalhesEvento> {
  late Map<String, dynamic> evento = {};
  List<dynamic> participantes = [];
  List<dynamic> comentarios = [];
  String novoComentario = '';
  bool isParticipating = false;
  bool isLoading = true;
  String erro = '';
  LatLng? _localizacao;

  String? _token;
  String? _idUtilizador;
  String? _nomeCriadorEvento;

  final TextEditingController _novoComentarioController =
      TextEditingController();

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
            content:
                Text('Você está offline. Por favor, conecte-se à internet.')),
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
    if (_idUtilizador != null) {
      await _fetchEventoDetails();
      await _fetchNomeCriadorEvento();
      await _fetchUsernamesComentarios();
      

    } else {
      setState(() {
        erro = 'Erro ao obter ID do utilizador';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchTokenAndProfile() async {
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
  }

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchEventoDetails() async {
  try {
    final eventoResponse = await http.get(
      Uri.parse('$baseUrl/evento/get/${widget.idEvento}'),
      headers: {'x-auth-token': _token!},
    );
    final eventoData = json.decode(eventoResponse.body);
    print('Dados do evento: $eventoData');

    // Processa a localização do evento
    List<String>? localizacao = eventoData['LOCALIZACAO']?.split(',');
    double? latitude;
    double? longitude;

    if (localizacao != null && localizacao.length >= 2) {
      latitude = double.tryParse(localizacao[0]);
      longitude = double.tryParse(localizacao[1]);

      if (latitude != null && longitude != null) {
        _localizacao = LatLng(latitude, longitude);
      }
    }

    final participantesResponse = await http.get(
      Uri.parse('$baseUrl/participantesevento/eventos/${widget.idEvento}/participantes'),
      headers: {'x-auth-token': _token!},
    );
    final participantesData = json.decode(participantesResponse.body);

    final comentariosResponse = await http.get(
      Uri.parse('$baseUrl/comentarios_evento/listevento/${widget.idEvento}'),
      headers: {'x-auth-token': _token!},
    );
    final comentariosData = json.decode(comentariosResponse.body);

    List<dynamic> comentariosList = [];
    if (comentariosData is List) {
      comentariosList = comentariosData;
    } else if (comentariosData is Map &&
        comentariosData.containsKey('error')) {}

    setState(() {
      evento = eventoData;
      participantes = participantesData.map((item) => item['User']).toList();
      comentarios = comentariosList;
      isParticipating = participantes
          .any((p) => p['ID_FUNCIONARIO'] == int.parse(_idUtilizador!));
      isLoading = false;
    });
  } catch (error) {
    print('Erro: $error');
    setState(() {
      erro = 'Erro ao carregar dados.';
      isLoading = false;
    });
  }
}

  Future<void> _fetchNomeCriadorEvento() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/${evento['ID_CRIADOR']}'),
        headers: {'x-auth-token': _token!},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _nomeCriadorEvento = data['user_name'];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Erro ao obter nome do criador do evento')),
        );
      }
    } catch (error) {
      setState(() {
        erro = 'Erro ao obter nome do criador do evento.';
      });
    }
  }

  Future<void> _fetchUsernamesComentarios() async {
    for (var comentario in comentarios) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/user/${comentario['ID_FUNCIONARIO']}'),
          headers: {'x-auth-token': _token!},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            comentario['username'] = data['user_name'];
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erro ao obter nome do autor do comentário')),
          );
        }
      } catch (error) {
        setState(() {
          erro = 'Erro ao obter nome do autor do comentário.';
        });
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      DateTime dateTime = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      print('Erro ao analisar a data: $e');
      return 'Data inválida';
    }
  }

  Future<void> _addComentario() async {
    if (novoComentario.trim().isEmpty) return;

    try {
      // Enviar o comentário
      final response = await http.post(
        Uri.parse('$baseUrl/comentarios_evento/create'),
        headers: {
          'x-auth-token': _token!, // Inclui o token de autenticação
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'ID_FUNCIONARIO': _idUtilizador,
          'DESCRICAO': novoComentario,
          'ID_EVENTO': evento['ID_EVENTO'],
        }),
      );

      // Verificar se o comentário foi adicionado com sucesso
      if (response.statusCode == 200) {
        final comentarioAdicionado = json.decode(response.body);

        // Buscar o nome do utilizador para associar ao comentário
        final userResponse = await http.get(
          Uri.parse('$baseUrl/user/${_idUtilizador}'),
          headers: {'x-auth-token': _token!},
        );

        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          comentarioAdicionado['username'] = userData['user_name'];
        }

        // Atualizar a lista de comentários
        setState(() {
          comentarios.add(comentarioAdicionado);
          novoComentario = ''; // Limpar a variável de novo comentário
          _novoComentarioController
              .clear(); // Limpar o controlador da caixa de texto
        });

        // Mostrar uma mensagem de sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comentário enviado com sucesso!')),
        );
      } else {
        // Mostrar uma mensagem de confirmação pendente
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('O seu comentário aguarda confirmação.')),
        );
      }
    } catch (error) {
      // Capturar e exibir erros durante o envio do comentário
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao enviar comentário.')),
      );
    } finally {
      // Limpar a caixa de texto independentemente do resultado
      setState(() {
        novoComentario = '';
        _novoComentarioController.clear();
      });
    }
  }

  Future<void> _deleteComentario(int idComentario) async {
    try {
      await http.delete(
          Uri.parse('$baseUrl/comentarios_evento/delete/$idComentario'));
      setState(() {
        comentarios.removeWhere(
            (comentario) => comentario['ID_COMENTARIO'] == idComentario);
      });
    } catch (error) {
      setState(() {
        erro = 'Erro ao apagar comentário.';
      });
    }
  }

  Future<void> _participarEvento() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/participantesevento/participantes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'ID_FUNCIONARIO': _idUtilizador,
          'ID_EVENTO': evento['ID_EVENTO'],
        }),
      );

      final userResponse = await http.get(
        Uri.parse('$baseUrl/user/$_idUtilizador'),
        headers: {'x-auth-token': _token!},
      );

      if (userResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        final userName = userData['user_name'];

        setState(() {
          isParticipating = true;
          participantes.add({
            'ID_FUNCIONARIO': int.parse(_idUtilizador!),
            'user_name': userName
          });
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao obter nome do utilizador')),
        );
      }
    } catch (error) {
      setState(() {
        erro = 'Erro ao participar do evento.';
      });
    }
  }

  Future<void> _deixarEvento() async {
    try {
      await http.delete(
        Uri.parse(
            '$baseUrl/participantesevento/participantesdelete/$_idUtilizador/${evento['ID_EVENTO']}'),
      );

      setState(() {
        isParticipating = false;
        participantes.removeWhere((participante) =>
            participante['ID_FUNCIONARIO'] == int.parse(_idUtilizador!));
      });
    } catch (error) {
      setState(() {
        erro = 'Erro ao deixar o evento.';
      });
    }
  }

  Future<void> _partilharEvento() async {
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
                        '@${loggedInUser['user_name']} partilhou este evento: ${evento['NOME_EVENTO']}',
                  }),
                );

                if (notificationResponse.statusCode == 201) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Evento partilhado com sucesso!'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro ao partilhar evento.'),
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
        erro = 'Erro ao partilhar evento.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro!),
        ),
      );
    }
  }

  Future<void> _shareEvento() async {
    final String linkEvento = '$baseUrl/evento/${widget.idEvento}';

    // Use o Share para compartilhar o link em redes sociais
    await Share.share('Confira este evento: $linkEvento');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link compartilhado: $linkEvento')),
    );
  }

  Future<void> _apagarEvento() async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/evento/delete/${widget.idEvento}'),
        headers: {'x-auth-token': _token!},
      );

      Navigator.pop(context, true);
    } catch (error) {
      setState(() {
        erro = 'Erro ao apagar evento.';
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchReportTypes() async {
  final response = await http.get(Uri.parse('$baseUrl/reporttopicos/list'));

  if (response.statusCode == 200) {
    List<dynamic> data = json.decode(response.body);
    // Retorna os tópicos com ID e NOME_TOPICO
    return data.map<Map<String, dynamic>>((item) => {
      'ID_TOPICO': item['ID_TOPICO'],
      'NOME_TOPICO': item['NOME_TOPICO'],
    }).toList();
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
    final url = Uri.parse('$baseUrl/reporteventos/create');

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

  String _getFullImageUrl(String relativeUrl) {
    return '$baseUrl/$relativeUrl';
  }

  Future<void> _navigateToEditarEvento() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditEventPage(eventData: evento)),
    );

    if (result == true) {
      _fetchTokenAndProfile();
      _fetchEventoDetails();
      setState(() {});
    }
  }

  void _submitRating(int comentarioId, double rating) async {
    try {
      final response = await http.post(
        Uri.parse(
            '$baseUrl/reviews_comentarios_evento/comentario/$comentarioId'),
        headers: {
          'x-auth-token':
              _token!, // Adiciona o token de autenticação se necessário
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          'ID_COMENTARIO': comentarioId,
          'ID_CRIADOR': _idUtilizador,
          'REVIEW': rating,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submetida com sucesso!')),
        );
      } else {
        print('Erro na resposta: ${response.body}');
        throw Exception('Erro ao submeter review');
      }
    } catch (e) {
      print('Erro ao submeter review: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao submeter review: $e')),
      );
    }
  }

  void _showReviewDialog(BuildContext context, int comentarioId) async {
    try {
      // Obter os dados de review
      final reviewData = await _fetchReviewData(comentarioId);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Review'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Média de Reviews: ${reviewData['averageReview']}'),
                Text('Número de Reviews: ${reviewData['reviewCount']}'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RatingBar.builder(
                      initialRating:
                          0, // Permite que o utilizador comece a partir de 0
                      minRating: 0.5,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemSize: 30.0, // Define o tamanho das estrelas
                      itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                      itemBuilder: (context, _) => const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      onRatingUpdate: (rating) {
                        _submitRating(comentarioId, rating);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      // Lidar com qualquer erro aqui
      print('Erro ao carregar os dados de review: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchReviewData(int comentarioId) async {
    final response = await http.get(
      Uri.parse(
          '$baseUrl/reviews_comentarios_evento/comentario/average/$comentarioId'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.containsKey('averageReview')) {
        return data; // Retorna os dados se a review existir
      } else {
        // Se não houver reviews, retorna um valor padrão
        return {
          'averageReview': 0.0,
          'reviewCount': 0,
        };
      }
    } else {
      // Lidar com erros HTTP
      return {
        'averageReview': 0.0,
        'reviewCount': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          evento['NOME_EVENTO'] ?? 'Evento',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (evento['ID_CRIADOR'].toString() == _idUtilizador)
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _apagarEvento,
              color: const Color.fromARGB(255, 230, 72, 61),
            ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareEvento,
          ),
        ],
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Criado por: @${_nomeCriadorEvento ?? evento['ID_CRIADOR']}',
              ),
              Text(
                'Data: ${evento['DATA_EVENTO'] != null ? _formatDate(evento['DATA_EVENTO']) : 'Data não disponível'}',
              ),
              SizedBox(
                height: 200,
                child: _localizacao != null
                    ? GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _localizacao!,
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('selected-location'),
                            position: _localizacao!,
                          ),
                        },
                        zoomControlsEnabled: true,
                        myLocationEnabled: true,
                      )
                    : const Center(child: Text('Localização indisponível')),
              ),
              Text(
                'Tipo de Evento: ${evento['TIPO_EVENTO'] ?? 'Tipo não disponível'}',
              ),
              const SizedBox(height: 10),
              evento['foto'] != null && evento['foto'].isNotEmpty
                  ? Image.network(_getFullImageUrl(evento['foto']))
                  : Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Text('Nenhuma imagem disponível'),
                      ),
                    ),
              const SizedBox(height: 10),
              if (evento['ID_CRIADOR'].toString() == _idUtilizador)
                ElevatedButton(
                  onPressed: _navigateToEditarEvento,
                  child: const Text('Editar Evento'),
                ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AlbumFotosPage(idEvento: evento['ID_EVENTO']),
                    ),
                  );
                },
                child: const Text('Álbum de Fotos'),
              ),
              const SizedBox(height: 10),
              isParticipating
                  ? ElevatedButton(
                      onPressed: _deixarEvento,
                      child: const Text('Deixar de Participar'),
                    )
                  : ElevatedButton(
                      onPressed: _participarEvento,
                      child: const Text('Participar'),
                    ),
              const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _partilharEvento,
                  child: const Text('Partilhar com colaboradores'),
                  ),
              const SizedBox(height: 20),
              const Text(
                'Participantes:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (var participante in participantes)
                Text('@${participante['user_name'] ?? 'Nome não encontrado'}'),
              const SizedBox(height: 20),
              const Text(
                'Comentários:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (var comentario in comentarios)
                Column(
                  children: [
                    /*
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
                    ),*/
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
                              onPressed: () => sendReport(
                                  context, comentario['ID_COMENTARIO']),
                            ),
                        ],
                      ),
                      onLongPress: () {
                        _showReviewDialog(context, comentario['ID_COMENTARIO']);
                      },
                    ),
                    const Divider(),
                  ],
                ),
              TextField(
                controller: _novoComentarioController,
                onChanged: (value) => setState(() => novoComentario = value),
                decoration: const InputDecoration(
                  labelText: 'Adicionar Comentário',
                ),
              ),
              ElevatedButton(
                onPressed: _addComentario,
                child: const Text('Comentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}