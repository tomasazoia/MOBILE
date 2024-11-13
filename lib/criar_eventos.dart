import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ip.dart';
import 'criar_localizacao.dart';

class CreateEventPage extends StatefulWidget {
  @override
  _CreateEventPageState createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  String _nomeEvento = '';
  String _tipoEvento = '';
  DateTime? _dataEvento;
  String _localizacao = '';
  String? _selectedArea;
  String? _selectedSubArea;
  int _numParticipantes = 0;
  File? _foto;
  LatLng? _selectedPosition;

  String? _idCriador;
  String? _token;
  List<dynamic> areas = [];
  List<dynamic> subareas = [];

  bool _fotoSelecionada = false;
  bool _isLoading = true;

  bool _isFormActive = false;
  bool _isCheckingStatus = true;

  Future<void> _checkFormStatus() async {
    try {
      final response =
          await http.get(Uri.parse('$baseUrl/formularios/status/2'));

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

  @override
  void initState() {
    super.initState();
    _checkFormStatus();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token de autenticação não encontrado')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {'x-auth-token': _token!},
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
      final response = await http.get(Uri.parse('$baseUrl/subarea/list'));
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
    } on SocketException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Você está offline. Por favor, conecte-se à internet.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ocorreu um erro: $e')),
      );
    }
  }

  Future<void> _createEvent() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_idCriador == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao obter ID do criador')),
        );
        return;
      }

      if (_selectedArea == null ||
          _selectedSubArea == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Por favor, preencha todos os campos obrigatórios')),
        );
        return;
      }

      try {
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/evento/create'),
        );

        request.fields['ID_CRIADOR'] = _idCriador!;
        request.fields['NOME_EVENTO'] = _nomeEvento;
        request.fields['TIPO_EVENTO'] = _tipoEvento;
        request.fields['DATA_EVENTO'] = _dataEvento?.toIso8601String() ?? '';
        request.fields['LOCALIZACAO'] = _localizacao; // Envia a localização
        request.fields['ID_AREA'] = _selectedArea!;
        request.fields['ID_SUB_AREA'] = _selectedSubArea!;
        request.fields['N_PARTICIPANTES'] = _numParticipantes.toString();
        request.fields['DISPONIBILIDADE'] = false.toString();

        if (_foto != null) {
          request.files
              .add(await http.MultipartFile.fromPath('foto', _foto!.path));
        }

        request.headers['x-auth-token'] = _token!;

        var response = await request.send();

        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Evento criado com sucesso e aguardando aprovação do administrador')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao criar evento')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocorreu um erro: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _foto = File(pickedFile.path);
        _fotoSelecionada = true;
      }
    });
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
        _localizacao =
            '${_selectedPosition!.latitude}, ${_selectedPosition!.longitude}';
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataEvento ?? now,
      firstDate: now,
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _dataEvento) {
      setState(() {
        _dataEvento = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dataEvento ?? DateTime.now()),
    );
    if (picked != null) {
      setState(() {
        final now = _dataEvento ?? DateTime.now();
        _dataEvento =
            DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      });
    }
  }

  void _showCreateSubAreaDialog() {
    String newSubAreaName = '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Criar Nova Subárea'),
          content: TextField(
            onChanged: (value) {
              newSubAreaName = value;
            },
            decoration: const InputDecoration(labelText: 'Nome da Subárea'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Criar'),
              onPressed: () {
                if (newSubAreaName.isNotEmpty) {
                  _createSubArea(newSubAreaName);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Novo Evento'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isFormActive
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Nome do Evento'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira o nome do evento';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _nomeEvento = value!;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Tipo de Evento'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira o tipo do evento';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _tipoEvento = value!;
                          },
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            await _selectDate();
                            await _selectTime();
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Data e Hora do Evento',
                                hintText: 'Selecione a data e a hora',
                              ),
                              controller: TextEditingController(
                                text: _dataEvento != null
                                    ? "${_dataEvento!.toLocal().toShortDateString()} ${TimeOfDay.fromDateTime(_dataEvento!).format(context)}"
                                    : '',
                              ),
                              validator: (value) {
                                if (_dataEvento == null) {
                                  return 'Por favor, selecione a data e hora do evento';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Área'),
                          value: _selectedArea,
                          items: areas.map<DropdownMenuItem<String>>((area) {
                            return DropdownMenuItem<String>(
                              value: area['ID_AREA'].toString(),
                              child: Text(area['NOME_AREA']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedArea = value;
                              if (_selectedArea != null) {
                                _fetchSubAreas(_selectedArea!);
                              } else {
                                subareas =
                                    []; // Limpar subáreas se nenhuma área estiver selecionada
                              }
                            });
                          },
                          validator: (value) {
                            if (value == null ||
                                !areas.any((area) =>
                                    area['ID_AREA'].toString() == value)) {
                              return 'Por favor, selecione uma área';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration:
                                    const InputDecoration(labelText: 'Subárea'),
                                value: _selectedSubArea,
                                items: subareas
                                    .map<DropdownMenuItem<String>>((subarea) {
                                  final nomeSubarea =
                                      subarea['NOME_SUBAREA'] as String?;
                                  return DropdownMenuItem<String>(
                                    value: subarea['ID_SUB_AREA']?.toString(),
                                    child: Text(
                                        nomeSubarea ?? 'Nome não disponível'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedSubArea = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Por favor, selecione uma subárea';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: _showCreateSubAreaDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Número de Participantes'),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null ||
                                int.tryParse(value) == null ||
                                int.parse(value) <= 0) {
                              return 'Por favor, insira um número válido de participantes';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            _numParticipantes = int.parse(value!);
                          },
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _pickImage,
                          child: Text(_fotoSelecionada
                              ? 'Foto Selecionada'
                              : 'Selecionar Foto'),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            onPressed: _createEvent,
                            child: const Text('Criar Evento'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    'Não é possível criar um evento novo neste momento. Por favor, tente novamente mais tarde.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18.0, color: Colors.red),
                  ),
                ),
    );
  }
}

extension DateTimeFormatting on DateTime {
  String toShortDateString() {
    return "${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/${year}";
  }
}