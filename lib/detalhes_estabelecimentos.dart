import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'ip.dart';

class DetalhesLocal extends StatefulWidget {
  final int idLocal;

  DetalhesLocal({required this.idLocal});

  @override
  _DetalhesLocalState createState() => _DetalhesLocalState();
}

class _DetalhesLocalState extends State<DetalhesLocal> {
  late Map<String, dynamic> local;
  bool isLoading = true;
  String erro = '';
  String? _token;
  String? _idUtilizador;
  List<dynamic> areas = [];
  List<dynamic> comentarios = [];
  LatLng? _localizacao;
  double _userRating = 0.0;
  bool _isLoading = true;
  String novoComentario = '';
  final TextEditingController _comentarioController = TextEditingController();
  double _averageRating = 0.0;
  int? reviewCount;
  bool hasError = false;
  bool _hasReviewed = false;

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
    if (_idUtilizador != null) {
      await _fetchLocalDetails();
      await _fetchAreas();
      await _fetchComentarios();
      await _fetchUsernamesComentarios();
      await _fetchNumReviews();
      await _checkUserReview();
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
        _idUtilizador = data['ID_FUNCIONARIO']?.toString() ?? '';
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

  Future<void> _fetchLocalDetails() async {
    try {
      final localResponse = await http.get(
        Uri.parse('$baseUrl/locais/get/${widget.idLocal}'),
        headers: {'x-auth-token': _token!},
      );

      if (localResponse.statusCode == 200) {
        final localData = json.decode(localResponse.body);

        List<String>? localizacao = localData['LOCALIZACAO']?.split(',');
        double? latitude;
        double? longitude;

        if (localizacao != null && localizacao.length >= 2) {
          latitude = double.tryParse(localizacao[0]);
          longitude = double.tryParse(localizacao[1]);
        }

        setState(() {
          local = localData;
          if (latitude != null && longitude != null) {
            _localizacao = LatLng(latitude, longitude);
          }
          isLoading = false;
        });

        // Atualiza a média das avaliações após obter detalhes do local
        _averageRating = await _fetchAverageRating();
        reviewCount = await _fetchNumReviews();
      } else {
        setState(() {
          erro =
              'Erro ao carregar dados do local. Código: ${localResponse.statusCode}';
          isLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        erro = 'Erro ao carregar dados: $error';
        isLoading = false;
      });
    }
  }

  Future<void> _fetchAreas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/area/list'));
      if (response.statusCode == 200) {
        setState(() {
          areas = json.decode(response.body);
        });
      }
    } catch (error) {
      setState(() {
        erro = 'Erro ao carregar áreas: $error';
      });
    }
  }

  Future<void> _fetchComentarios() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comentarios_local/listlocal/${widget.idLocal}'),
        headers: {'x-auth-token': _token!},
      );
      if (response.statusCode == 200) {
        setState(() {
          comentarios = json.decode(response.body);
        });
      } else {
        setState(() {
          erro = 'Erro ao carregar comentários. Código: ${response.statusCode}';
        });
      }
    } catch (error) {
      setState(() {
        erro = 'Erro ao carregar comentários: $error';
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

  Future<int> _fetchNumReviews() async {
    final url = '$baseUrl/review/local/get/${widget.idLocal}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Retorna o número de reviews extraído dos dados
        return data['count'] ?? 0;
      } else {
        throw Exception('Erro ao carregar os dados');
      }
    } catch (error) {
      print('Erro: $error');
      // Retorna 0 em caso de erro
      return 0;
    }
  }

  Future<double> _fetchAverageRating() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/review/average/local/${widget.idLocal}'),
        headers: {
          'x-auth-token': _token!,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['averageReview'] as num?)?.toDouble() ?? 0.0;
      } else {
        throw Exception('Falha ao carregar média das avaliações');
      }
    } catch (error) {
      print('Erro ao buscar média das avaliações: $error');
      return 0.0;
    }
  }

  Future<void> _checkUserReview() async {
    final hasReviewed = await _fetchReviewsLoggedUser();
    setState(() {
      _hasReviewed = hasReviewed;
    });
  }

  Future<bool> _fetchReviewsLoggedUser() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/review/localreviews/${widget.idLocal}'));

      if (response.statusCode == 200) {
        List<dynamic> jsonResponse = json.decode(response.body);

        for (var review in jsonResponse) {
          if (review['ID_CRIADOR'].toString() == _idUtilizador.toString()) {
            return true;
          }
        }
        return false; 
      } else {
        throw Exception('Falha ao carregar as reviews');
      }
    } catch (e) {
      print('Erro: $e');
      return false;
    }
  }

  // Função para lidar com o corpo da resposta de erro
  void _handleErrorResponse(String responseBody) {
    try {
      final Map<String, dynamic> errorData = json.decode(responseBody);
      final String errorMessage = errorData['error'] ?? 'Erro desconhecido';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      // Se a resposta não for um JSON válido, exiba uma mensagem genérica
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar a resposta: $responseBody')),
      );
    }
  }

  Future<void> _submitRating(double rating) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/review/local/${widget.idLocal}'),
        headers: {
          'x-auth-token': _token!,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'ID_LOCAL': widget.idLocal,
          'ID_CRIADOR': _idUtilizador,
          'REVIEW': rating,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avaliação enviada com sucesso!')),
        );

        // Atualize o rating do usuário local
        setState(() {
          _userRating = rating;
        });

        // Atualize a média das avaliações
        double newAverageRating = await _fetchAverageRating();
        //--------------------------------------------------------------------------
        int newReviewCount = await _fetchNumReviews();
        setState(() {
          _averageRating = newAverageRating;
          reviewCount = newReviewCount;
        });
      } else {
        // Trata o erro e exibe a mensagem correta
        _handleErrorResponse(response.body);
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar avaliação: $error')),
      );
    }
  }

  Future<void> _submitComentario(String comentario) async {
    if (comentario.trim().isEmpty) return;

    try {
      //enviar comentário
      final response = await http.post(
        Uri.parse('$baseUrl/comentarios_local/create'),
        headers: {
          'x-auth-token': _token!,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'ID_FUNCIONARIO': _idUtilizador,
          'DESCRICAO': comentario,
          'ID_LOCAL': widget.idLocal,
        }),
      );

      //comentário foi adicionado com sucesso
      if (response.statusCode == 200) {
        final comentarioAdicionado = json.decode(response.body);

        //buscar nome do user para associar ao comentário
        final userResponse = await http.get(
          Uri.parse('$baseUrl/user/$_idUtilizador'),
          headers: {'x-auth-token': _token!},
        );

        if (userResponse.statusCode == 200) {
          final userData = json.decode(userResponse.body);
          comentarioAdicionado['NOME_UTILIZADOR'] = userData['user_name'];
        }

        //atualizar a lista de comentários
        setState(() {
          comentarios.add(comentarioAdicionado);
          novoComentario = '';
          _comentarioController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comentário enviado com sucesso!')),
        );
        //aguardar confirmação do comentário
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('O seu comentário aguarda confirmação.')),
        );
      }
      //erro ao enviar comentário
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao enviar comentário.')),
      );
    } finally {
      // Limpar o campo de comentário independentemente do resultado
      setState(() {
        novoComentario = '';
        _comentarioController.clear();
      });
    }
  }

  Future<void> _shareLocal() async {
    final String linkLocal = '$baseUrl/locais/${widget.idLocal}';

    // Use o Share para compartilhar o link em redes sociais
    await Share.share('Confira este evento: $linkLocal');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link compartilhado: $linkLocal')),
    );
  }

  Future<void> _deleteComentario(int idComentario) async {
    try {
      await http.delete(
        Uri.parse('$baseUrl/comentarios_local/delete/$idComentario'),
        headers: {'x-auth-token': _token!},
      );
      setState(() {
        comentarios.removeWhere(
            (comentario) => comentario['ID_COMENTARIO'] == idComentario);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comentário apagado com sucesso!')),
      );
    } catch (error) {
      setState(() {
        erro = 'Erro ao apagar comentário: $error';
      });
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
    final url = Uri.parse('$baseUrl/reportlocais/create');

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

  Future<void> _partilharLocal() async {
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
                        '@${loggedInUser['user_name']} partilhou este local: ${local['DESIGNACAO_LOCAL']}',
                  }),
                );

                if (notificationResponse.statusCode == 201) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Local partilhado com sucesso!'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro ao partilhar local.'),
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
        erro = 'Erro ao partilhar local.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(erro!),
        ),
      );
    }
  }

  String _getFullImageUrl(String? imagePath) {
    if (imagePath == null) {
      return '';
    }
    if (imagePath.startsWith('http')) {
      return imagePath;
    } else {
      return '$baseUrl/$imagePath';
    }
  }

  String _getAreaNameById(String idArea) {
    for (var area in areas) {
      if (area['ID_AREA'].toString() == idArea) {
        return area['NOME_AREA'];
      }
    }
    return 'Área desconhecida';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalhes do Local'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (erro.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalhes do Local'),
        ),
        body: Center(
          child: Text(erro),
        ),
      );
    }

    // Função para formatar o preço
    String _formatPrice(double price) {
      if (price == 0) {
        return 'Preço por pessoa: Gratuito/Entrada Livre';
      } else if (price <= 10) {
        return 'Preço por pessoa: 1 a 10 EUR';
      } else if (price <= 20) {
        return 'Preço por pessoa: 11 a 20 EUR';
      } else if (price <= 30) {
        return 'Preço por pessoa: 21 a 30 EUR';
      } else if (price <= 40) {
        return 'Preço por pessoa: 31 a 40 EUR';
      } else {
        return 'Preço por pessoa: Mais de 40 EUR';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          local['DESIGNACAO_LOCAL'] ?? 'Detalhes do Local',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareLocal,
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
                      )
                    : const Center(child: Text('Localização indisponível')),
              ),
              const SizedBox(height: 10),
              Text(
                  'Área: ${_getAreaNameById(local['ID_AREA']?.toString() ?? '')}'),
              const SizedBox(height: 10),
              Text(_formatPrice(local['PRECO']?.toDouble() ?? 0.0),
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Text('Review: '),
              RatingBarIndicator(
                rating: _averageRating, // Use a média das avaliações
                itemBuilder: (context, index) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                itemCount: 5,
                itemSize: 20.0,
                direction: Axis.horizontal,
              ),
              Text('(${reviewCount ?? 0})'),
              const SizedBox(height: 20),
              local['foto'] != null && local['foto'].isNotEmpty
                  ? Image.network(_getFullImageUrl(local['foto']))
                  : Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                          child: Text('Nenhuma imagem disponível'))),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _partilharLocal,
                child: const Text('Partilhar com colaboradores'),
              ),
              const SizedBox(height: 20),
              if (_hasReviewed == false) ...[
                const SizedBox(height: 20),
                const Text('Deixe a sua avaliação:'),
                RatingBar.builder(
                  initialRating: _userRating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                  itemBuilder: (context, _) => const Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  onRatingUpdate: (rating) {
                    _submitRating(rating);
                  },
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Comentários:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              for (var comentario in comentarios)
                Column(
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
                              onPressed: () => sendReport(
                                  context, comentario['ID_COMENTARIO']),
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                  ],
                ),
              TextField(
                controller: _comentarioController,
                onChanged: (value) => setState(() => novoComentario = value),
                decoration: const InputDecoration(
                  labelText: 'Adicionar Comentário',
                ),
              ),
              ElevatedButton(
                onPressed: () => _submitComentario(_comentarioController.text),
                child: const Text('Comentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}