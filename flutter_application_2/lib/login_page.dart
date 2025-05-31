import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'google_sign_in_service.dart';
import 'routes.dart'; // ルート設定をインポート

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // メール/パスワードによるログイン処理
  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // ログイン成功ならホーム画面へ遷移
      if (userCredential.user != null && mounted) {
        Navigator.pushReplacementNamed(context, Routes.home);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // メール/パスワードによる新規登録処理
  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // 登録成功ならホーム画面へ遷移
      if (userCredential.user != null && mounted) {
        Navigator.pushReplacementNamed(context, Routes.home);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Google サインイン処理
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userCredential = await GoogleSignInService().signInWithGoogle();
      // サインイン成功ならホーム画面へ遷移
      if (userCredential != null && userCredential.user != null && mounted) {
        Navigator.pushReplacementNamed(context, Routes.home);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login / Register"),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // メールアドレス入力
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  return null;
                },
              ),
              // パスワード入力
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              // エラーメッセージの表示
              if (_errorMessage != null) ...[
                const SizedBox(height: 8.0),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16.0),
              // ログイン・登録ボタン
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _signIn();
                            }
                          },
                          child: const Text("Login"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _register();
                            }
                          },
                          child: const Text("Register"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    // Google Sign-In ボタンの追加
                    ElevatedButton(
                      onPressed: _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/google_logo.png',
                            height: 24.0,
                          ),
                          const SizedBox(width: 8.0),
                          const Text("Sign in with Google"),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
