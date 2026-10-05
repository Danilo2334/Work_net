import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isCandidate = true;

  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  bool _acceptedTerms = false;
  bool _isLoading = false;

  String _password = '';

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _passwordConfirmController =
      TextEditingController();

  int get _strengthScore {
    if (_password.isEmpty) return 0;

    int score = 0;

    if (_password.length >= 8) score++;
    if (_password.contains(RegExp(r'[A-Z]'))) score++;
    if (_password.contains(RegExp(r'[a-z]'))) score++;
    if (_password.contains(RegExp(r'[0-9!@#\$&*~._-]'))) {
      score++;
    }

    return score;
  }

  String get _strengthText {
    switch (_strengthScore) {
      case 0:
        return '';
      case 1:
        return 'Débil';
      case 2:
        return 'Regular';
      case 3:
        return 'Buena';
      case 4:
        return 'Fuerte';
      default:
        return '';
    }
  }

  Color get _strengthColor {
    switch (_strengthScore) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.green;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm =
        _passwordConfirmController.text;

    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        passwordConfirm.isEmpty) {
      _showMessage(
        'Completa todos los campos.',
        isError: true,
      );
      return;
    }

    if (password != passwordConfirm) {
      _showMessage(
        'Las contraseñas no coinciden.',
        isError: true,
      );
      return;
    }

    if (!_acceptedTerms) {
      _showMessage(
        'Debes aceptar los términos y condiciones.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          'http://127.0.0.1:8000/api/register/',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'password': password,
          'password_confirm': passwordConfirm,
          'role': _isCandidate
              ? 'candidato'
              : 'empresa',
        }),
      );

      dynamic data;

      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = null;
      }

      if (!mounted) return;

      if (response.statusCode == 201) {
        _showMessage(
          data?['message'] ??
              'Usuario registrado correctamente.',
        );

        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _passwordConfirmController.clear();

        setState(() {
          _password = '';
          _acceptedTerms = false;
        });
      } else {
        _showMessage(
          _formatErrors(
            data?['errors'],
          ),
          isError: true,
        );
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'No fue posible conectar con el servidor.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatErrors(dynamic errors) {
    if (errors == null) {
      return 'No fue posible realizar el registro.';
    }

    if (errors is Map) {
      final messages = <String>[];

      errors.forEach((key, value) {
        if (value is List) {
          messages.add(
            value.join(', '),
          );
        } else {
          messages.add(
            value.toString(),
          );
        }
      });

      if (messages.isEmpty) {
        return 'No fue posible realizar el registro.';
      }

      return messages.join('\n');
    }

    return errors.toString();
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    const primaryBlue = Color(0xFF0F62FE);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.arrowLeft,
            color: Colors.black87,
          ),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius:
                    BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.work,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Work_net',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          const Center(
            child: Text(
              'Registro',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const CircleAvatar(
            backgroundColor: primaryBlue,
            radius: 14,
            child: Icon(
              LucideIcons.user,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 16.0,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Text(
              'Crea tu cuenta',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                    color:
                        const Color(0xFF1E293B),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Únete a la plataforma líder para talento y empresas de alto impacto',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 24),

            // Candidato / Empresa
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isCandidate =
                                    true;
                              });
                            },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _isCandidate
                              ? primaryBlue
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Icon(
                              LucideIcons.user,
                              size: 18,
                              color: _isCandidate
                                  ? Colors.white
                                  : Colors.grey
                                      .shade600,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Text(
                              'Soy Candidato',
                              style: TextStyle(
                                color: _isCandidate
                                    ? Colors.white
                                    : Colors.grey
                                        .shade700,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isCandidate =
                                    false;
                              });
                            },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: !_isCandidate
                              ? primaryBlue
                              : Colors.transparent,
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Icon(
                              LucideIcons.building,
                              size: 18,
                              color: !_isCandidate
                                  ? Colors.white
                                  : Colors.grey
                                      .shade600,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Text(
                              'Soy Empresa',
                              style: TextStyle(
                                color: !_isCandidate
                                    ? Colors.white
                                    : Colors.grey
                                        .shade700,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botones sociales
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.public,
                      size: 18,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Google',
                      style: TextStyle(
                        color: Colors.black87,
                      ),
                    ),
                    style:
                        OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      side: BorderSide(
                        color:
                            Colors.grey.shade300,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(
                      Icons
                          .business_center_outlined,
                      size: 18,
                      color:
                          Color(0xFF0A66C2),
                    ),
                    label: const Text(
                      'LinkedIn',
                      style: TextStyle(
                        color: Colors.black87,
                      ),
                    ),
                    style:
                        OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      side: BorderSide(
                        color:
                            Colors.grey.shade300,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Colors.grey.shade300,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Text(
                    'O COMPLETA TUS DATOS',
                    style: TextStyle(
                      color:
                          Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Nombre
            _buildLabel(
              'Nombre completo',
            ),

            TextField(
              controller: _nameController,
              enabled: !_isLoading,
              textInputAction:
                  TextInputAction.next,
              decoration: _inputDecoration(
                hint:
                    'Ej. Mariana Valenzuela',
                icon: LucideIcons.user,
              ),
            ),

            const SizedBox(height: 16),

            // Correo
            _buildLabel(
              'Correo electrónico profesional',
            ),

            TextField(
              controller: _emailController,
              enabled: !_isLoading,
              keyboardType:
                  TextInputType.emailAddress,
              textInputAction:
                  TextInputAction.next,
              decoration: _inputDecoration(
                hint:
                    'mariana.v@techlead.io',
                icon: LucideIcons.mail,
                suffixIcon: const Icon(
                  LucideIcons.checkCircle2,
                  color: Colors.green,
                  size: 18,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Contraseña
            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                _buildLabel(
                  'Contraseña',
                ),
                if (_password.isNotEmpty)
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration:
                            BoxDecoration(
                          color:
                              _strengthColor,
                          shape:
                              BoxShape.circle,
                        ),
                      ),
                      const SizedBox(
                        width: 6,
                      ),
                      Text(
                        'Seguridad: $_strengthText',
                        style: TextStyle(
                          color:
                              _strengthColor,
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 8),

            TextField(
              controller:
                  _passwordController,
              enabled: !_isLoading,
              obscureText:
                  _obscurePassword,
              textInputAction:
                  TextInputAction.next,
              onChanged: (value) {
                setState(() {
                  _password = value;
                });
              },
              decoration: _inputDecoration(
                hint: '••••••••••••',
                icon: LucideIcons.lock,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? LucideIcons.eye
                        : LucideIcons.eyeOff,
                    size: 18,
                    color:
                        Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword =
                          !_obscurePassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Indicador fortaleza contraseña
            Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 300,
                    ),
                    height: 4,
                    decoration:
                        BoxDecoration(
                      color:
                          _strengthScore >= 1
                              ? _strengthColor
                              : Colors.grey
                                  .shade200,
                      borderRadius:
                          BorderRadius.circular(
                        2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 300,
                    ),
                    height: 4,
                    decoration:
                        BoxDecoration(
                      color:
                          _strengthScore >= 2
                              ? _strengthColor
                              : Colors.grey
                                  .shade200,
                      borderRadius:
                          BorderRadius.circular(
                        2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 300,
                    ),
                    height: 4,
                    decoration:
                        BoxDecoration(
                      color:
                          _strengthScore >= 3
                              ? _strengthColor
                              : Colors.grey
                                  .shade200,
                      borderRadius:
                          BorderRadius.circular(
                        2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration:
                        const Duration(
                      milliseconds: 300,
                    ),
                    height: 4,
                    decoration:
                        BoxDecoration(
                      color:
                          _strengthScore >= 4
                              ? _strengthColor
                              : Colors.grey
                                  .shade200,
                      borderRadius:
                          BorderRadius.circular(
                        2,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Confirmar contraseña
            _buildLabel(
              'Confirmar contraseña',
            ),

            TextField(
              controller:
                  _passwordConfirmController,
              enabled: !_isLoading,
              obscureText:
                  _obscurePasswordConfirm,
              textInputAction:
                  TextInputAction.done,
              onSubmitted: (_) {
                if (!_isLoading) {
                  _register();
                }
              },
              decoration: _inputDecoration(
                hint: '••••••••••••',
                icon: LucideIcons.lock,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePasswordConfirm
                        ? LucideIcons.eye
                        : LucideIcons.eyeOff,
                    size: 18,
                    color:
                        Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePasswordConfirm =
                          !_obscurePasswordConfirm;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Términos
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _acceptedTerms,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() {
                              _acceptedTerms =
                                  value ??
                                      false;
                            });
                          },
                    activeColor:
                        primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      children: const [
                        TextSpan(
                          text:
                              'Acepto los ',
                        ),
                        TextSpan(
                          text:
                              'Términos de Servicio',
                          style: TextStyle(
                            color:
                                primaryBlue,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' y la ',
                        ),
                        TextSpan(
                          text:
                              'Política de Privacidad',
                          style: TextStyle(
                            color:
                                primaryBlue,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' de WorkNet.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Botón registrar
            ElevatedButton(
              onPressed:
                  _isLoading ? null : _register,
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryBlue,
                disabledBackgroundColor:
                    primaryBlue.withOpacity(
                  0.6,
                ),
                padding:
                    const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .center,
                      children: [
                        Text(
                          'Registrarme gratis',
                          style: TextStyle(
                            color:
                                Colors.white,
                            fontSize: 16,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          LucideIcons
                              .arrowRight,
                          color:
                              Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 24),

            // Información inferior
            Container(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration: BoxDecoration(
                color:
                    const Color(
                  0xFFF1F5F9,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.all(
                      10,
                    ),
                    decoration:
                        BoxDecoration(
                      color: Colors.white,
                      shape:
                          BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(
                            0.05,
                          ),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.award,
                      color:
                          primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          '+85,000 candidatos calificados',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          '12 días promedio de colocación laboral',
                          style:
                              TextStyle(
                            color:
                                Colors.grey
                                    .shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  '¿Ya tienes cuenta? ',
                  style: TextStyle(
                    color:
                        Colors.grey.shade700,
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      context.go(
                    '/login',
                  ),
                  child: const Text(
                    'Inicia sesión',
                    style: TextStyle(
                      color:
                          primaryBlue,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(
    String text,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8.0,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight:
              FontWeight.bold,
          fontSize: 13,
          color:
              Color(0xFF1E293B),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color:
            Colors.grey.shade400,
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        size: 18,
        color:
            Colors.grey.shade600,
      ),
      suffixIcon:
          suffixIcon,
      filled: true,
      fillColor:
          Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 16,
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        borderSide:
            BorderSide(
          color:
              Colors.grey.shade200,
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        borderSide:
            const BorderSide(
          color:
              Color(0xFF0F62FE),
        ),
      ),
    );
  }
}