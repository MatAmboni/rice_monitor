import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../main.dart';
import '../utils/app_theme.dart';
import '../utils/ui_components.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static String _lastUsedEmail = '';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final DatabaseReference usersRef = FirebaseDatabase.instance.ref('users');

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    if (_lastUsedEmail.isNotEmpty) {
      _emailController.text = _lastUsedEmail;
      _rememberEmail = true;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      final snapshot = await usersRef.get();
      if (snapshot.exists) {
        final users = snapshot.value as Map<dynamic, dynamic>;
        final foundUser = users.entries.firstWhere(
          (e) => e.value['email'] == email && e.value['password'] == password,
          orElse: () => const MapEntry(null, null),
        );

        if (foundUser.key != null) {
          if (_rememberEmail) {
            _lastUsedEmail = email;
          } else {
            _lastUsedEmail = '';
          }

          if (!mounted) return;
          _showMessage("Login bem-sucedido!");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MyApp()),
          );
        } else {
          if (!mounted) return;
          _showMessage("Email ou senha incorretos.");
        }
      } else {
        if (!mounted) return;
        _showMessage("Nenhum usuário encontrado.");
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage("Erro ao conectar ao servidor.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Informe o email.';
    }
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!regex.hasMatch(text)) {
      return 'Email invalido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Informe a senha.';
    }
    if (text.length < 6) {
      return 'Use pelo menos 6 caracteres.';
    }
    return null;
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool checking = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Recuperar senha'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Informe seu email para verificar se ele esta cadastrado.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: checking
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: checking
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          final emailError = _validateEmail(email);
                          if (emailError != null) {
                            _showMessage(emailError);
                            return;
                          }

                          setDialogState(() {
                            checking = true;
                          });

                          try {
                            final snapshot = await usersRef.get();
                            bool found = false;
                            if (snapshot.exists) {
                              final users = snapshot.value as Map<dynamic, dynamic>;
                              found = users.values.any((u) => u['email'] == email);
                            }

                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                            if (found) {
                              _showMessage(
                                'Email encontrado. Entre em contato com o suporte para redefinir a senha.',
                              );
                            } else {
                              _showMessage('Email nao encontrado.');
                            }
                          } catch (_) {
                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                            _showMessage('Falha ao verificar o email.');
                          }
                        },
                  child: checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verificar'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 1000;
          final double formWidth = isDesktop ? 460 : 560;

          final brandingContent = Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _BrandHeader(),
              SizedBox(height: 24),
              Text(
                "Sistema de gerenciamento hídrico",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          );

          final formContent = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: formWidth),
            child: GlassCard(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Entrar na plataforma',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      decoration: InputDecoration(
                        labelText: "Senha",
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppTheme.primary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppTheme.primary,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberEmail,
                          onChanged: (value) {
                            setState(() {
                              _rememberEmail = value ?? false;
                            });
                          },
                        ),
                        const Expanded(child: Text('Lembrar meu email')),
                        TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text('Esqueci a senha'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _login,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login, color: Colors.white),
                        label: Text(_isLoading ? "Entrando..." : "Entrar"),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Não tem conta? Cadastre-se",
                        style: TextStyle(color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/rice_field.jpeg'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x8A0E2E27), Color(0xCC091A15)],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 36 : 24,
                      vertical: isDesktop ? 28 : 48,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: isDesktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: brandingContent),
                                const SizedBox(width: 42),
                                formContent,
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                brandingContent,
                                const SizedBox(height: 32),
                                formContent,
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Icon(
            Icons.water_drop_rounded,
            color: Colors.white,
            size: 64,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Rice Monitor",
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const Text(
          "Sistema Inteligente de Irrigação",
          style: TextStyle(fontSize: 16, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
