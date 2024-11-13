import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../detalhes_eventos.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../ip.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
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
    await _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    final response = await http.get(Uri.parse('$baseUrl/evento/list'));
    if (response.statusCode == 200) {
      List events = json.decode(response.body);
      Map<DateTime, List<dynamic>> eventsMap = {};
      for (var event in events) {
        DateTime eventDate = DateTime.parse(event['DATA_EVENTO']);
        DateTime formattedEventDate =
            DateTime(eventDate.year, eventDate.month, eventDate.day);
        if (!eventsMap.containsKey(formattedEventDate)) {
          eventsMap[formattedEventDate] = [];
        }
        eventsMap[formattedEventDate]!.add(event);
      }
      setState(() {
        _events = eventsMap;
      });
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário de Eventos'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2023, 01, 01),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              if (_getEventsForDay(selectedDay).isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetalhesEventosDia(
                      date: selectedDay,
                      events: _getEventsForDay(selectedDay),
                    ),
                  ),
                );
              }
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(color: Colors.white),
              markersMaxCount: 1,
              markersAlignment: Alignment.bottomCenter,
              markerSizeScale: 0.15,
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.black),
              weekendStyle: TextStyle(color: Colors.black),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    bottom: 1,
                    child: _buildEventsMarker(day, events),
                  );
                }
                return null;
              },
            ),
            eventLoader: _getEventsForDay,
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final events = _getEventsForDay(_selectedDay);
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          title: Text(event['NOME_EVENTO']),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DetalhesEvento(idEvento: event['ID_EVENTO']),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventsMarker(DateTime date, List<dynamic> events) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue,
      ),
      width: 16.0,
      height: 16.0,
      child: Center(
        child: Text(
          '${events.length}',
          style: const TextStyle().copyWith(
            color: Colors.white,
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }
}

class DetalhesEventosDia extends StatelessWidget {
  final DateTime date;
  final List<dynamic> events;

  const DetalhesEventosDia({required this.date, required this.events, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Eventos em ${date.toLocal()}'.split(' ')[0]),
      ),
      body: ListView.builder(
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return ListTile(
            title: Text(event['NOME_EVENTO']),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      DetalhesEvento(idEvento: event['ID_EVENTO']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
