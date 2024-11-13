import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ip.dart';
import 'criar_localizacao.dart';
import 'escolher_estabelecimentos.dart';

class CreateLocalPage extends StatefulWidget {
  @override
  _CreateLocalPageState createState() => _CreateLocalPageState();
}

class _CreateLocalPageState extends State<CreateLocalPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedArea;
  String? _selectedSubArea;
  String _designacaoLocal = '';
  String _localizacao = '';
  double? _preco;
  File? _foto;
  LatLng? _selectedPosition;

  String? _idCriador;
  String? _token;
  List<dynamic> areas = [];
  List<dynamic> subareas = [];

  double? _review;
  final List<double> reviewValues =List.generate(10, (index) => (index + 1) * 0.5);

  bool _fotoSelecionada = false;
  bool _isLoading = true;
  bool _isFormActive = false;
  bool _isCheckingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkFormStatus();
    _checkConnectivityAndInitData();
  }

  Future<void> _checkFormStatus() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/formularios/status/3'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _isFormActive = data['ATIVO'];
          _isCheckingStatus = false;
        });
      } else {
        throw Exception('Erro ao verificar o status do formulário.');
      }
    } catch (e) {
      setState(() {
        _isCheckingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao verificar o status do formulário: $e')),
      );
    }
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
    try {
      await _fetchTokenAndProfile();
      await _fetchAreas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTokenAndProfile() async {
    _token = await _getAuthToken();

    if (_token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token de autenticação não encontrado')),
        );
        setState(() {
          _isLoading = false;
        });
      }
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
      if (mounted) {
        setState(() {
          _idCriador = data['ID_FUNCIONARIO'].toString();
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao obter dados do utilizador')),
        );
      }
    }
  }

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchAreas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/area/list'));
      if (response.statusCode == 200) {
        setState(() {
          areas = json.decode(response.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar áreas')),
        );
      }
    } on SocketException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro: $e')),
      );
    }
  }

  Future<void> _fetchSubAreas(String areaId) async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/subarea/list?ID_AREA=$areaId'));
      if (response.statusCode == 200) {
        final List<dynamic> fetchedSubareas = json.decode(response.body);
        setState(() {
          subareas = fetchedSubareas;
          if (_selectedSubArea != null &&
              !subareas.any((subarea) =>
                  subarea['ID_SUB_AREA'].toString() == _selectedSubArea)) {
            _selectedSubArea = null;
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar subáreas')),
        );
      }
    } on SocketException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro: $e')),
      );
    }
  }

  Future<void> _createSubArea(String nomeSubArea) async {
    if (_selectedArea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Por favor, selecione uma área antes de criar uma subárea')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/subarea/checknormal'),
        headers: {
          'x-auth-token': _token!,
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'NOME_SUBAREA': nomeSubArea,
          'ID_AREA': _selectedArea,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subárea criada com sucesso')),
        );
        _fetchSubAreas(_selectedArea!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao criar subárea')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro: $e')),
      );
    }
  }

  /*Future<void> _createLocal() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_idCriador == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao obter ID do criador')),
          );
        }
        return;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/locais/create'),
      );

      request.fields['ID_CRIADOR'] = _idCriador!;
      request.fields['ID_AREA'] = _selectedArea!;
      request.fields['ID_SUB_AREA'] = _selectedSubArea ?? '';
      request.fields['DESIGNACAO_LOCAL'] = _designacaoLocal;
      request.fields['LOCALIZACAO'] = _selectedPosition != null
          ? '${_selectedPosition!.latitude},${_selectedPosition!.longitude}'
          : '';
      request.fields['PRECO'] = _preco?.toString() ?? '';
      request.fields['REVIEW'] = _review?.toString() ?? '';

      if (_foto != null) {
        request.files.add(await http.MultipartFile.fromPath('foto', _foto!.path));
      }

      if (_token != null) {
        request.headers['x-auth-token'] = _token!;
      }

      try {
        final response = await request.send();

        if (mounted) {
          if (response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Local criado com sucesso')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LocaisPage()),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Erro ao criar estabelecimento')),
            );
          }
        }
      } catch (e) {
        print('Erro ao enviar requisição: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao criar estabelecimento')),
          );
        }
      }
    }
  }*/

  //cria local e adiciona review do criador na tabela das reviews
  Future<void> _createLocal() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_idCriador == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao obter ID do criador')),
          );
        }
        return;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/locais/create'),
      );

      request.fields['ID_CRIADOR'] = _idCriador!;
      request.fields['ID_AREA'] = _selectedArea!;
      request.fields['ID_SUB_AREA'] = _selectedSubArea ?? '';
      request.fields['DESIGNACAO_LOCAL'] = _designacaoLocal;
      request.fields['LOCALIZACAO'] = _selectedPosition != null
          ? '${_selectedPosition!.latitude},${_selectedPosition!.longitude}'
          : '';
      request.fields['PRECO'] = _preco?.toString() ?? '';
      request.fields['REVIEW'] = _review?.toString() ?? '';

      if (_foto != null) {
        request.files
            .add(await http.MultipartFile.fromPath('foto', _foto!.path));
      }

      if (_token != null) {
        request.headers['x-auth-token'] = _token!;
      }

      try {
        final response = await request.send();

        if (response.statusCode == 201) {
          // A criação do local foi bem-sucedida
          final responseBody = await response.stream.bytesToString();
          final createdLocalId = json.decode(responseBody)['ID_LOCAL'];

          // Adiciona a review se existir
          if (_review != null) {
            final reviewResponse = await http.post(
              Uri.parse('$baseUrl/review/create'),
              headers: {
                'Content-Type': 'application/json',
                if (_token != null) 'x-auth-token': _token!,
              },
              body: json.encode({
                'ID_CRIADOR': _idCriador!,
                'REVIEW': _review!,
                'ID_LOCAL': createdLocalId,
              }),
            );

            if (reviewResponse.statusCode == 201) {
              // Review criada com sucesso
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Local e Review criados com sucesso')),
              );
            } else {
              // Falha ao criar review
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Local criado, mas falha ao adicionar a review')),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Local criado com sucesso')),
            );
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LocaisPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao criar estabelecimento')),
          );
        }
      } catch (e) {
        print('Erro ao enviar requisição: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao criar estabelecimento')),
          );
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    if (mounted) {
      setState(() {
        if (pickedFile != null) {
          _foto = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _selectLocation(BuildContext context) async {
    LatLng? selectedPosition = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectLocationPage(),
      ),
    );

    if (selectedPosition != null) {
      setState(() {
        _selectedPosition = selectedPosition;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Novo Estabelecimento'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isFormActive
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        if (areas.isEmpty)
                          const Center(child: CircularProgressIndicator())
                        else
                          DropdownButtonFormField<String>(
                            value: _selectedArea,
                            hint: const Text('Selecione uma área'),
                            onChanged: (newValue) {
                              setState(() {
                                _selectedArea = newValue!;
                                _fetchSubAreas(_selectedArea!);
                              });
                            },
                            items: areas.map<DropdownMenuItem<String>>((area) {
                              return DropdownMenuItem<String>(
                                value: area['ID_AREA'].toString(),
                                child: Text(area['NOME_AREA']),
                              );
                            }).toList(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor selecione uma área';
                              }
                              return null;
                            },
                          ),
                        if (_selectedArea != null)
                          if (subareas.isEmpty)
                            const Center(child: CircularProgressIndicator())
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedSubArea,
                              hint: const Text('Selecione uma subárea'),
                              onChanged: (newValue) {
                                setState(() {
                                  _selectedSubArea = newValue!;
                                });
                              },
                              items: subareas
                                  .map<DropdownMenuItem<String>>((subarea) {
                                return DropdownMenuItem<String>(
                                  value: subarea['ID_SUB_AREA'].toString(),
                                  child: Text(subarea['NOME_SUBAREA']),
                                );
                              }).toList(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor selecione uma subárea';
                                }
                                return null;
                              },
                            ),
                        TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Designação do Local'),
                          onSaved: (value) {
                            _designacaoLocal = value!;
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor insira a designação do local';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          decoration:
                              const InputDecoration(labelText: 'Localização'),
                          readOnly: true,
                          controller: TextEditingController(
                            text: _selectedPosition == null
                                ? ''
                                : '${_selectedPosition!.latitude}, ${_selectedPosition!.longitude}',
                          ),
                          onTap: () => _selectLocation(context),
                          validator: (value) {
                            if (_selectedPosition == null) {
                              return 'Por favor selecione a localização';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'Preço'),
                          keyboardType: TextInputType.number,
                          onSaved: (value) {
                            _preco = double.tryParse(value ?? '');
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor insira o preço';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Por favor insira um valor válido';
                            }
                            return null;
                          },
                        ),
                        DropdownButtonFormField<double>(
                          decoration:
                              const InputDecoration(labelText: 'Minha Review'),
                          items: reviewValues.map((value) {
                            return DropdownMenuItem<double>(
                              value: value,
                              child: Text(value.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _review = value;
                            });
                          },
                          value: _review,
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor selecione uma review';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _review = value;
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _pickImage,
                              child: const Text('Escolher Foto'),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            if (_foto == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Por favor selecione uma foto'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              setState(() {
                                _fotoSelecionada = false;
                              });
                            } else {
                              setState(() {
                                _fotoSelecionada = true;
                              });
                              _createLocal();
                            }
                          },
                          child: const Text('Criar Estabelecimento'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            final nomeSubArea =
                                await _showCreateSubAreaDialog();
                            if (nomeSubArea != null && nomeSubArea.isNotEmpty) {
                              _createSubArea(nomeSubArea);
                            }
                          },
                          child: const Text('Criar Nova Subárea'),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    'Não é possível criar um estabelecimento novo neste momento. Por favor, tente novamente mais tarde.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18.0, color: Colors.red),
                  ),
                ),
    );
  }

  Future<String?> _showCreateSubAreaDialog() async {
    String? nomeSubArea;
    await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Criar Nova Subárea'),
          content: TextField(
            onChanged: (value) {
              nomeSubArea = value;
            },
            decoration: const InputDecoration(hintText: 'Nome da Subárea'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(nomeSubArea);
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
    return nomeSubArea;
  }
}
