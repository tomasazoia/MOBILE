import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'escolher_eventos.dart';
import 'criar_conta.dart';
import 'ip.dart';
import 'esqueci_password.dart';
import 'primeiro_login.dart';
import 'register_google.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'register_facebook.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';


class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  List<Map<String, String>> _profiles = [];
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadProfiles().then((_) {
      if (_profiles.isNotEmpty) {
        _showSavedProfilesDialog();
      }
    });
  }

  Future<void> _loginWithFacebook() async {
  try {
    // Realiza o login com o Facebook
    final LoginResult result = await FacebookAuth.instance.login();

    if (result.status == LoginStatus.success) {
      final AccessToken accessToken = result.accessToken!;
      
      // Cria as credenciais do Firebase usando o token de acesso do Facebook
      final AuthCredential credential = FacebookAuthProvider.credential(accessToken.token);

      // Tenta fazer login com as credenciais do Facebook
      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

        // Se o login for bem-sucedido, continua com a autenticação no backend
        await _handleBackendAuth(userCredential);

      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          // Obtém o email da exceção
          final String email = e.email!;
          
          // Obtém o provedor existente
          final List<String> signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
          
          // Solicita ao usuário para se autenticar com o provedor existente
          // Aqui você pode pedir ao usuário para fazer login novamente ou vincular as credenciais
          
          // Exemplo de como vincular credenciais:
          User? user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Vincula a nova credencial ao usuário existente
            await user.linkWithCredential(credential);

            // Depois de vincular, pode continuar com o processo de autenticação no backend
            userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            await _handleBackendAuth(userCredential);
          }
        } else {
          _showError('Erro ao fazer login com Facebook: ${e.message}');
        }
      }
    } else if (result.status == LoginStatus.cancelled) {
      _showError('Login com Facebook foi cancelado.');
    } else {
      _showError('Erro ao fazer login com Facebook: ${result.message}');
    }
  } catch (e) {
    _showError('Erro ao fazer login com Facebook: $e');
  }
}

Future<void> _handleBackendAuth(UserCredential userCredential) async {
  // Utilize o accessToken para autenticar no seu backend
  final response = await http.post(
    Uri.parse('$baseUrl/auth/facebook-login'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'user_mail': userCredential.user?.email ?? '',
      'user_name': userCredential.user?.displayName ?? '',
    }),
  );

  if (response.statusCode == 200) {
    final responseData = jsonDecode(response.body);
    String token = responseData['token'];
    bool firstLogin = responseData['firstLogin'];

    // Armazena o token
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);

    // Mensagem de feedback
    Fluttertoast.showToast(
      msg: firstLogin
          ? 'Bem-vindo ao seu primeiro login com Facebook!'
          : 'Login com Facebook bem-sucedido!',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
    );

    // Navega para a página apropriada com base no status do login
    if (firstLogin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => RegisterFacebookPage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => EventosPage()),
      );
    }
  } else {
    _showError('Erro ao comunicar com o servidor. Código de status: ${response.statusCode}');
  }
}

  Future<void> _loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        UserCredential userCredential =
            await _auth.signInWithCredential(credential);

        final response = await http.post(
          Uri.parse('$baseUrl/auth/google-login-mobile'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'user_mail': userCredential.user?.email ?? '',
            'user_name': userCredential.user?.displayName ?? '',
            'user_photo': userCredential.user?.photoURL ?? '',
          }),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          String token = responseData['token'];
          bool firstLogin = responseData['firstLogin'];

          // Armazenar o token
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);

          // Mensagem de feedback
          Fluttertoast.showToast(
            msg: firstLogin
                ? 'Bem-vindo ao seu primeiro login!'
                : 'Login com Google bem-sucedido!',
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
          );

          if (firstLogin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => RegisterGooglePage()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => EventosPage()),
            );
          }
        } else {
          _showError(
              'Erro ao comunicar com o servidor. Código de status: ${response.statusCode}');
        }
      }
    } catch (e) {
      _showError('Erro ao fazer login com Google: $e');
    }
  }

  void _showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
    );
  }

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesString = prefs.getString('user_profiles') ?? '[]';

    try {
      final List<dynamic> profilesList = jsonDecode(profilesString);
      setState(() {
        _profiles = profilesList.map((profile) {
          final profileMap = profile as Map<String, dynamic>;
          return {
            'email': profileMap['email'] as String? ?? '',
            'password': profileMap['password'] as String? ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print('Erro ao carregar perfis: $e');
    }
  }

  Future<void> _saveProfile(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesString = prefs.getString('user_profiles') ?? '[]';

    try {
      final List<dynamic> profilesList = jsonDecode(profilesString);
      profilesList.removeWhere((profile) => profile['email'] == email);
      profilesList.add({'email': email, 'password': password});
      await prefs.setString('user_profiles', jsonEncode(profilesList));

      setState(() {
        _profiles = profilesList.map((profile) {
          final profileMap = profile as Map<String, dynamic>;
          return {
            'email': profileMap['email'] as String? ?? '',
            'password': profileMap['password'] as String? ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print('Erro ao salvar perfil: $e');
    }
  }

  Future<void> _deleteProfile(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesString = prefs.getString('user_profiles') ?? '[]';

    try {
      final List<dynamic> profilesList = jsonDecode(profilesString);
      profilesList.removeWhere((profile) => profile['email'] == email);
      await prefs.setString('user_profiles', jsonEncode(profilesList));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados guardados do perfil eliminados com sucesso.'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      print('Erro ao deletar perfil: $e');
    }
  }

  Future<void> _loginWithProfile(Map<String, String> profile) async {
    if (profile['email'] != null && profile['password'] != null) {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Você está offline. Por favor, conecte-se à internet.'),
          ),
        );
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/login-mobile'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'user_mail': profile['email']!,
            'user_password': profile['password']!,
          }),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          String token = responseData['token'];

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_email', profile['email']!);
          await prefs.setString('user_password', profile['password']!);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => EventosPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email ou senha inválidos. Tente novamente.'),
            ),
          );
        }
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: $error')),
        );
      }
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Você está offline. Por favor, conecte-se à internet.'),
          ),
        );
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/login-mobile'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'user_mail': _emailController.text,
            'user_password': _passwordController.text,
          }),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          String token = responseData['token'];
          bool firstLogin = responseData['firstLogin'];

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setString('user_email', _emailController.text);
          await prefs.setString('user_password', _passwordController.text);

          if (_rememberMe) {
            await _saveProfile(_emailController.text, _passwordController.text);
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  firstLogin ? PrimeiroLoginPage() : EventosPage(),
            ),
          );
        } else {
          // Extrair a mensagem de erro do corpo da resposta
          final responseData = jsonDecode(response.body);
          String errorMessage = responseData['message'];

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: $error')),
        );
      }
    }
  }

  void _showProfileDeletionConfirmationDialog(String email) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text(
              'Tem certeza de que deseja eliminar o perfil com email $email?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteProfile(email);
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _showSavedProfilesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Perfis Guardados'),
          content: SizedBox(
            height: 200,
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _profiles.length,
                    itemBuilder: (context, index) {
                      final profile = _profiles[index];
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 0),
                        title: Text(
                          profile['email'] ?? 'Sem Email',
                          overflow: TextOverflow.ellipsis,
                        ),
                        onLongPress: () {
                          _showProfileDeletionConfirmationDialog(
                              profile['email']!);
                        },
                        onTap: () {
                          Navigator.of(context).pop();
                          _loginWithProfile(profile);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10.0),
                const Text(
                  'Toque e mantenha pressionado para eliminar.',
                  style: TextStyle(fontSize: 12.0, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Fechar'),
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
        title: Container(),
        flexibleSpace: Align(
          alignment: Alignment.center,
          child: Image.asset('assets/logo-softinsa.png',
              fit: BoxFit.cover, height: kToolbarHeight),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.blue, Color.fromARGB(255, 13, 58, 95)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    _buildForm(),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const EsqueciPasswordPage()),
                        );
                      },
                      child: const Text(
                        'Esqueci a minha palavra-passe',
                        style: TextStyle(
                          color: Colors.black,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _login,
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: Color.fromARGB(255, 13, 58, 95),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    ElevatedButton(
                      onPressed: _loginWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shadowColor: Colors.grey,
                        elevation: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/google_logo.png',
                            height: 24.0,
                          ),
                          const SizedBox(width: 10),
                          const Text('Login com Google'),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _loginWithFacebook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        shadowColor: Colors.grey,
                        elevation: 5,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.facebook, size: 24.0, color: Colors.white),
                          const SizedBox(width: 10),
                          const Text('Login com Facebook'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20.0),
                    if (_profiles.isNotEmpty) ...[
                      TextButton(
                        onPressed: _showSavedProfilesDialog,
                        child: const Text(
                          'Perfis Guardados',
                          style: TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ContaCreate()),
                        );
                      },
                      child: const Text(
                        'Criar Conta',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Digite o seu email',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o seu email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20.0),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Senha',
                  hintText: 'Digite a sua senha',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a sua senha';
                  }
                  return null;
                },
                obscureText: true,
              ),
              CheckboxListTile(
                title: const Text(
                  'Lembrar dados',
                  style: TextStyle(color: Colors.black),
                ),
                value: _rememberMe,
                onChanged: (bool? value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}