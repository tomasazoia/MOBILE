import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'criar_estabelecimentos.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'detalhes_estabelecimentos.dart';
import 'dart:convert';
import 'ip.dart';

class LocaisAreaPage extends StatefulWidget {
  final int idArea, classificacaoMin, classificacaoMax;
  const LocaisAreaPage(
      {super.key,
      required this.idArea,
      required this.classificacaoMin,
      required this.classificacaoMax});
  @override
  _LocaisAreaPageState createState() => _LocaisAreaPageState();
}

class _LocaisAreaPageState extends State<LocaisAreaPage> {
  List<dynamic> locais = [];
  bool _isLoading = false;

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
        _isLoading = false;
      });
      return;
    }
    _fetchLocais();
  }

  Future<void> _fetchLocais() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String url = widget.idArea == -1
          ? '$baseUrl/locais/listvalidados' // URL para listar todos os locais validados
          : '$baseUrl/locais/listarea/${widget.idArea}'; // URL para listar locais por área

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> locaisData = json.decode(response.body);

        // Agora precisamos de obter a classificação média de cada local
        List<dynamic> locaisComClassificacao = [];
        for (var local in locaisData) {
          final mediaResponse = await http.get(
            Uri.parse('$baseUrl/review/average/local/${local['ID_LOCAL']}'),
          );

          if (mediaResponse.statusCode == 200) {
            final mediaData = json.decode(mediaResponse.body);
            local['averageReview'] = mediaData['averageReview'] ?? 0.0;
          } else {
            local['averageReview'] = 0.0;
          }

          // Apenas adiciona os locais que estão dentro do intervalo de classificação escolhido
          if (local['averageReview'] >= widget.classificacaoMin &&
              local['averageReview'] <= widget.classificacaoMax) {
            locaisComClassificacao.add(local);
          }
        }

        setState(() {
          locais = locaisComClassificacao;
          locais.sort((a, b) => a['ID_LOCAL'].compareTo(b['ID_LOCAL']));
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar locais: $error')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToCreateLocalPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateLocalPage()),
    );

    if (result == true) {
      _fetchLocais();
    }
  }

  Future<void> _navigateToLocalPage(int idLocal) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalhesLocal(idLocal: idLocal)),
    );

    if (result == true) {
      _fetchLocais();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          title: const Text("Estabelecimentos"),
          //automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                await _navigateToCreateLocalPage();
                _fetchLocais();
              },
            ),
          ],
        ),
        body: _buildLocaisList(),
      ),
    );
  }

  Widget _buildLocaisList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (locais.isEmpty) {
      return const Center(
        child: Text(
          'Não há estabelecimentos disponíveis.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    } else {
      return ListView.builder(
        itemCount: locais.length,
        itemBuilder: (context, index) {
            final local = locais[index];
            return _buildLocalCard(
              context,
              local['DESIGNACAO_LOCAL'],
              local['foto'],
              'DETALHES',
              local['ID_LOCAL'],
              local['averageReview'], // Passar a média aqui
            );
          }
      );
    }
  }

  String _getFullImageUrl(String imagePath) {
    if (imagePath.startsWith('http')) {
      return imagePath;
    } else {
      return '$baseUrl/$imagePath';
    }
  }

  Widget _buildStarRating(double rating) {
    int fullStars = rating.floor(); // Número de estrelas completas
    bool hasHalfStar =
        (rating - fullStars) >= 0.5; // Verifica se há meia estrela
    int emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0); // Estrelas vazias

    List<Widget> stars = [];

    // Estrelas completas
    for (int i = 0; i < fullStars; i++) {
      stars.add(const Icon(Icons.star, color: Colors.orange));
    }

    // Meia estrela
    if (hasHalfStar) {
      stars.add(const Icon(Icons.star_half, color: Colors.orange));
    }

    // Estrelas vazias
    for (int i = 0; i < emptyStars; i++) {
      stars.add(const Icon(Icons.star_border, color: Colors.orange));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: stars,
    );
  }

  Widget _buildLocalCard(
    BuildContext context,
    String title,
    String imagePath,
    String buttonText,
    int idLocal,
    double averageReview, // Classificação média
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildStarRating(averageReview), // Exibe as estrelas
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                _navigateToLocalPage(idLocal);
              },
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}