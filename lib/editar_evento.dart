import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../ip.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'criar_localizacao.dart';

class EditEventPage extends StatefulWidget {
  final dynamic eventData;

  const EditEventPage({Key? key, required this.eventData}) : super(key: key);

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeEventoController = TextEditingController();
  final TextEditingController _tipoEventoController = TextEditingController();
  final TextEditingController _localizacaoController = TextEditingController();
  final TextEditingController _nParticipantesController =
      TextEditingController();

  String? _token;
  String? _errorMessage;
  DateTime? _dataEvento;
  File? _selectedImage;
  LatLng? _selectedPosition;

  bool _isLoading = true;

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
    _token = await _getAuthToken();
    _populateControllers();
  }

  Future<String?> _getAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  void _populateControllers() {
    if (widget.eventData != null) {
      _nomeEventoController.text = widget.eventData['NOME_EVENTO'];
      _tipoEventoController.text = widget.eventData['TIPO_EVENTO'];
      _localizacaoController.text = widget.eventData['LOCALIZACAO'];
      _nParticipantesController.text =
          widget.eventData['N_PARTICIPANTES'].toString();
      _dataEvento = DateTime.parse(widget.eventData['DATA_EVENTO']);
    }
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> formData = {
        'NOME_EVENTO': _nomeEventoController.text,
        'TIPO_EVENTO': _tipoEventoController.text,
        'DATA_EVENTO': _dataEvento!.toIso8601String(),
        'LOCALIZACAO': _localizacaoController.text,
        'N_PARTICIPANTES': int.parse(_nParticipantesController.text),
        'LATITUDE': _selectedPosition?.latitude,
        'LONGITUDE': _selectedPosition?.longitude,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/evento/update/${widget.eventData['ID_EVENTO']}'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': _token!,
        },
        body: jsonEncode(formData),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evento atualizado com sucesso')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erro ao atualizar evento: ${response.body}')),
          );
        }
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _dataEvento ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      setState(() {
        _dataEvento = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          _dataEvento?.hour ?? 0,
          _dataEvento?.minute ?? 0,
        );
      });
      await _selectTime(context);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: _dataEvento != null
          ? TimeOfDay(hour: _dataEvento!.hour, minute: _dataEvento!.minute)
          : TimeOfDay.now(),
    );
    if (selectedTime != null) {
      setState(() {
        final now = _dataEvento ?? DateTime.now();
        int selectedHour = selectedTime.hour + 1; // Ajuste para o fuso horário
        if (selectedHour >= 24) {
          selectedHour -= 24;
        }
        _dataEvento = DateTime(
          now.year,
          now.month,
          now.day,
          selectedHour,
          selectedTime.minute,
        );
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
        _localizacaoController.text =
            '${_selectedPosition!.latitude}, ${_selectedPosition!.longitude}';
      });
    }
  }

  @override
  void dispose() {
    _nomeEventoController.dispose();
    _tipoEventoController.dispose();
    _localizacaoController.dispose();
    _nParticipantesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Evento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.blue,
      ),
      body: widget.eventData != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nomeEventoController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Evento',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor insira o nome do evento';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _tipoEventoController,
                      decoration: const InputDecoration(
                        labelText: 'Tipo do Evento',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor insira o tipo do evento';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Data do Evento',
                        hintText: 'dd/mm/aaaa hh:mm',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () => _selectDate(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.access_time),
                              onPressed: () => _selectTime(context),
                            ),
                          ],
                        ),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: _dataEvento == null
                            ? ''
                            : '${_dataEvento!.day.toString().padLeft(2, '0')}/${_dataEvento!.month.toString().padLeft(2, '0')}/${_dataEvento!.year} ${_dataEvento!.hour.toString().padLeft(2, '0')}:${_dataEvento!.minute.toString().padLeft(2, '0')}',
                      ),
                      validator: (value) {
                        if (_dataEvento == null) {
                          return 'Por favor selecione a data e hora do evento';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _localizacaoController,
                      decoration: InputDecoration(
                        labelText: 'Localização',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.map),
                          onPressed: () => _selectLocation(context),
                        ),
                      ),
                      readOnly: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor insira a localização';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _nParticipantesController,
                      decoration: const InputDecoration(
                        labelText: 'Número de Participantes',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor insira o número de participantes';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Por favor insira um número válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _handleSubmit,
                      child: const Text('Guardar Alterações'),
                    ),
                  ],
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}