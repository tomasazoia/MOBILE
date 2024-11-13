import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'ip.dart';
import 'listar_estabelecimentos.dart';
import 'detalhes_estabelecimentos.dart';

class FiltrarEstabelecimentosReviews extends StatefulWidget {
  final int idArea;
  const FiltrarEstabelecimentosReviews({super.key, required this.idArea});
  @override
  State<FiltrarEstabelecimentosReviews> createState() => _FiltrarEstabelecimentosReviewsState();
}

class _FiltrarEstabelecimentosReviewsState
    extends State<FiltrarEstabelecimentosReviews> {
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
  }

  Widget _buildReviewList() {
    return _isLoading
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView(
            padding:
                const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocaisAreaPage(classificacaoMin: 0, classificacaoMax: 5, idArea: widget.idArea),
                      ),
                    );
                  },
                  child: const Text(
                    'Todas as Classificações',
                    style: TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocaisAreaPage(classificacaoMin: 4, classificacaoMax: 5, idArea: widget.idArea),
                      ),
                    );
                  },
                  child: const Text(
                    '4-5 Estrelas',
                    style: TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocaisAreaPage(classificacaoMin: 3, classificacaoMax: 4, idArea: widget.idArea),
                      ),
                    );
                  },
                  child: const Text(
                    '3-4 Estrelas',
                    style: TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocaisAreaPage(classificacaoMin: 2, classificacaoMax: 3, idArea: widget.idArea),
                      ),
                    );
                  },
                  child: const Text(
                    '2-3 Estrelas',
                    style: TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocaisAreaPage(classificacaoMin: 1, classificacaoMax: 2, idArea: widget.idArea),
                      ),
                    );
                  },
                  child: const Text(
                    '1-2 Estrelas',
                    style: TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocaisAreaPage(classificacaoMin: 0, classificacaoMax: 1, idArea: widget.idArea),
                      ),
                    );
                  },
                  child: const Text(
                    '0-1 Estrelas',
                    style: TextStyle(fontSize: 16.0),
                  ),
                ),
              ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtrar por Reviews'),
        backgroundColor: Colors.blue,
      ),
      body: _buildReviewList(),
    );
  }
}