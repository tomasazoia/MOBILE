import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'adicionar_foto.dart';
import 'ip.dart';

class AlbumFotosPage extends StatefulWidget {
  final int idEvento;

  const AlbumFotosPage({required this.idEvento, Key? key}) : super(key: key);

  @override
  _AlbumFotosPageState createState() => _AlbumFotosPageState();
}

class _AlbumFotosPageState extends State<AlbumFotosPage> {
  List<Map<String, String>> fotos = [];
  bool isLoading = false;
  String? _token;
  String? _idCriador;

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
        isLoading = false;
      });
      return;
    }

    await _initData();
  }

  Future<void> _initData() async {
    try {
      await _fetchTokenAndProfile();
      await _carregarFotos();
    } on SocketException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você está offline. Por favor, conecte-se à internet'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocorreu um erro: $e'),
        ),
      );
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

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'x-auth-token': _token!,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _idCriador = data['ID_FUNCIONARIO'].toString();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao obter dados do utilizador')),
        );
      }
    } on SocketException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você está offline. Por favor, conecte-se à internet.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocorreu um erro: $e')),
      );
    }
  }

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _carregarFotos() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response =
          await http.get(Uri.parse('$baseUrl/album/evento/${widget.idEvento}'));
      if (response.statusCode == 200) {
        List<dynamic> fotosList = jsonDecode(response.body);

        setState(() {
          fotos = fotosList.map((foto) {
            return {
              'foto': foto['foto'].toString(),
              'LEGENDA': foto['LEGENDA'].toString(),
            };
          }).toList();
        });
      } else {
        throw Exception('Erro ao carregar álbuns de fotos');
      }
    } catch (e) {
      print('Erro: $e');
      setState(() {
        fotos = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _deletarFoto(int index) async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/album/delete/${widget.idEvento}'),
        headers: {
          'x-auth-token': _token!,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          fotos.removeAt(index);
        });
      } else {
        throw Exception('Erro ao deletar a foto');
      }
    } catch (e) {
      print('Erro: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getFullImageUrl(String relativeUrl) {
    return '$baseUrl/$relativeUrl';
  }

  void _mostrarImagemFullscreen(String imageUrl, String legenda) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width,
                    maxHeight: MediaQuery.of(context).size.height,
                  ),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(_getFullImageUrl(imageUrl)),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    legenda,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Álbum de Fotos'),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddPhotoPage(
                    idEvento: widget.idEvento,
                    token: _token!,
                    idCriador: _idCriador!,
                  ),
                ),
              ).then((value) {
                if (value == true) {
                  _carregarFotos();
                }
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : fotos.isEmpty
              ? const Center(
                  child: Text('Nenhuma foto encontrada'),
                )
              : Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 4.0,
                          mainAxisSpacing: 4.0,
                        ),
                        itemCount: fotos.length,
                        itemBuilder: (BuildContext context, int index) {
                            return Stack(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    _mostrarImagemFullscreen(
                                        fotos[index]['foto']!,
                                        fotos[index]['LEGENDA']!);
                                  },
                                  child: Card(
                                    elevation: 2.0,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Image.network(
                                            _getFullImageUrl(
                                                fotos[index]['foto']!),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            fotos[index]['LEGENDA']!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      _deletarFoto(index);
                                    },
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }
                      ),
                    ),
                  ],
                ),
    );
  }
}
