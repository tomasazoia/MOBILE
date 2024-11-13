import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ip.dart';

class AddPhotoPage extends StatefulWidget {
  final int idEvento;
  final String token;
  final String idCriador;

  const AddPhotoPage({
    required this.idEvento,
    required this.token,
    required this.idCriador,
    Key? key,
  }) : super(key: key);

  @override
  _AddPhotoPageState createState() => _AddPhotoPageState();
}

class _AddPhotoPageState extends State<AddPhotoPage> {
  final _formKey = GlobalKey<FormState>();
  File? _foto;
  final TextEditingController _legendaController = TextEditingController();
  bool isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _foto = File(pickedFile.path);
      }
    });
  }

  Future<void> _addFoto() async {
    if (_foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecione uma foto')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/album/create'),
      );

      request.fields['ID_EVENTO'] = widget.idEvento.toString();
      request.fields['DATA_ADICAO'] = DateTime.now().toIso8601String();
      request.fields['ID_CRIADOR'] = widget.idCriador;
      request.fields['LEGENDA'] = _legendaController.text;

      if (_foto != null) {
        request.files
            .add(await http.MultipartFile.fromPath('foto', _foto!.path));
      }

      request.headers['x-auth-token'] = widget.token;

      setState(() {
        isLoading = true;
      });

      final response = await request.send();
      final responseBody = await http.Response.fromStream(response);

      setState(() {
        isLoading = false;
      });

      if (mounted) {
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto adicionada com sucesso')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao adicionar foto: ${responseBody.body}')),
          );
        }
      }
    } on SocketException catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você está offline. Por favor, conecte-se à internet.'),
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ocorreu um erro: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar Foto'),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _legendaController,
                      decoration: const InputDecoration(
                        labelText: 'Legenda',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor insira uma legenda';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_foto != null)
                      Image.file(
                        _foto!,
                        height: 200,
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Selecionar Foto'),
                      onPressed: _pickImage,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _addFoto,
                      child: const Text('Adicionar Foto'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}