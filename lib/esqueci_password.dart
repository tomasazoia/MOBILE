import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'ip.dart';
import 'criar_conta.dart';

class EsqueciPasswordPage extends StatefulWidget {
  const EsqueciPasswordPage({super.key});

  @override
  State<EsqueciPasswordPage> createState() => _EsqueciPasswordPageState();
}

class _EsqueciPasswordPageState extends State<EsqueciPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  int _step = 1;

  Future<void> _requestResetCode() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Verificar conectividade
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        Fluttertoast.showToast(
            msg: 'Você está offline. Por favor, conecte-se à internet.');
        return;
      }

      try {
        // Fazer a requisição para verificar se o e-mail existe
        final response = await http.get(Uri.parse('$baseUrl/user/list'));

        if (response.statusCode == 200) {
          List<dynamic> users = json.decode(response.body);
          bool emailExists =
              users.any((user) => user['user_mail'] == _emailController.text);

          if (emailExists) {
            final resetResponse = await http
                .post(
                  Uri.parse('$baseUrl/auth/request-password-reset'),
                  headers: <String, String>{'Content-Type': 'application/json'},
                  body: jsonEncode(
                      <String, String>{'user_mail': _emailController.text}),
                )
                .timeout(const Duration(seconds: 10));

            if (resetResponse.statusCode == 200) {
              Fluttertoast.showToast(
                  msg: 'Código de recuperação enviado para o seu e-mail.');
              setState(() {
                _step = 2;
              });
            } else {
              Fluttertoast.showToast(
                  msg: 'Erro ao solicitar recuperação de senha.');
            }
          } else {
            Fluttertoast.showToast(
                msg:
                    'Não há nenhuma conta criada com o e-mail ${_emailController.text}.');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ContaCreate()),
            );
          }
        } else {
          Fluttertoast.showToast(msg: 'Erro ao verificar e-mail.');
        }
      } catch (error) {
        Fluttertoast.showToast(msg: 'Erro ao conectar ao servidor: $error');
      }
    }
  }

  Future<void> _confirmResetCode() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/confirm-reset-code'),
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, String>{
            'user_mail': _emailController.text,
            'resetCode': _codeController.text,
          }),
        );
        if (response.statusCode == 200) {
          Fluttertoast.showToast(msg: 'Código validado com sucesso.');
          setState(() {
            _step = 3;
          });
        } else {
          Fluttertoast.showToast(msg: 'Código de recuperação inválido.');
        }
      } catch (e) {
        Fluttertoast.showToast(msg: 'Erro ao conectar ao servidor.');
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/reset-password'),
          headers: <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, String>{
            'user_mail': _emailController.text,
            'new_password': _newPasswordController.text,
          }),
        );
        if (response.statusCode == 200) {
          Fluttertoast.showToast(msg: 'Senha redefinida com sucesso.');
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          Fluttertoast.showToast(msg: 'Erro ao redefinir senha.');
        }
      } catch (e) {
        Fluttertoast.showToast(msg: 'Erro ao conectar ao servidor.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Image.asset('assets/logo-softinsa.png',
              fit: BoxFit.cover, height: kToolbarHeight),
        ),
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                kToolbarHeight -
                MediaQuery.of(context).padding.top,
          ),
          child: IntrinsicHeight(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.blue, Color.fromARGB(255, 13, 58, 95)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      'Recuperar Palavra-passe',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    _buildForm(),
                    const SizedBox(height: 20.0),
                    if (_step == 1)
                      ElevatedButton(
                        onPressed: _requestResetCode,
                        child: const Text(
                          'Solicitar Código',
                          style:
                              TextStyle(color: Color.fromARGB(255, 13, 58, 95)),
                        ),
                      )
                    else if (_step == 2)
                      ElevatedButton(
                        onPressed: _confirmResetCode,
                        child: const Text(
                          'Confirmar Código',
                          style:
                              TextStyle(color: Color.fromARGB(255, 13, 58, 95)),
                        ),
                      )
                    else if (_step == 3)
                      ElevatedButton(
                        onPressed: _resetPassword,
                        child: const Text(
                          'Redefinir Senha',
                          style:
                              TextStyle(color: Color.fromARGB(255, 13, 58, 95)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              if (_step == 1)
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Digite o seu e-mail',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o seu e-mail';
                    }
                    final emailRegex =
                        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Por favor, insira um e-mail válido';
                    }
                    return null;
                  },
                ),
              if (_step == 2)
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Código de Recuperação',
                    hintText: 'Digite o código recebido',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o código de recuperação';
                    }
                    return null;
                  },
                ),
              if (_step == 3)
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nova Senha',
                    hintText: 'Digite a nova senha',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira a nova senha';
                    }
                    return null;
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}