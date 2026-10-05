import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();

    final rememberMe =
        prefs.getBool('remember_me') ?? false;

    if (!rememberMe) {
      return;
    }

    final email =
        prefs.getString('remembered_email');

    if (!mounted) return;

    setState(() {
      _rememberMe = true;

      if (email != null) {
        _emailController.text = email;
      }
    });
  }

  Future<void> _login() async {
    final email =
        _emailController.text.trim();

    final password =
        _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        'Ingresa tu correo y contraseña.',
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
          'http://127.0.0.1:8000/api/login/',
        ),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      dynamic data;

      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = null;
      }

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Token retornado por Django
        final token = data is Map
            ? data['token']?.toString()
            : null;

        if (token == null || token.isEmpty) {
          _showMessage(
            'El servidor no devolvió un token de autenticación.',
            isError: true,
          );
          return;
        }

        // Datos del usuario retornados por Django
        final user = data is Map
            ? data['user']
            : null;

        if (user is! Map) {
          _showMessage(
            'La respuesta del servidor no es válida.',
            isError: true,
          );
          return;
        }

        final backendRole =
            user['role']
                ?.toString()
                .toLowerCase()
                .trim();

        final route =
            _routeForRole(backendRole);

        if (route == null) {
          _showMessage(
            'El rol de la cuenta no es válido.',
            isError: true,
          );
          return;
        }

        await _saveSession(
          user,
          backendRole ?? '',
          token,
        );

        if (!mounted) return;

        _showMessage(
          data is Map
              ? data['message']?.toString() ??
                  'Inicio de sesión correcto.'
              : 'Inicio de sesión correcto.',
        );

        context.go(route);
      } else {
        final errors = data is Map
            ? data['errors']
            : null;

        _showMessage(
          _formatErrors(errors),
          isError: true,
        );
      }
    } catch (_) {
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

  String? _routeForRole(String? role) {
    switch (role) {
      case 'candidato':
      case 'candidate':
        return '/candidate';

      case 'empresa':
      case 'company':
        return '/company';

      case 'administrador':
      case 'admin':
        return '/admin';

      default:
        return null;
    }
  }

  Future<void> _saveSession(
    Map user,
    String role,
    String token,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    if (_rememberMe) {
      await prefs.setBool(
        'remember_me',
        true,
      );

      await prefs.setString(
        'remembered_email',
        _emailController.text.trim(),
      );

      await prefs.setBool(
        'is_logged_in',
        true,
      );

      // Token de autenticación Django
      await prefs.setString(
        'auth_token',
        token,
      );

      final userId = user['id'];

      if (userId is int) {
        await prefs.setInt(
          'user_id',
          userId,
        );
      } else if (userId != null) {
        final parsedId =
            int.tryParse(userId.toString());

        if (parsedId != null) {
          await prefs.setInt(
            'user_id',
            parsedId,
          );
        }
      }

      await prefs.setString(
        'user_full_name',
        user['full_name']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'user_email',
        user['email']
                ?.toString() ??
            '',
      );

      await prefs.setString(
        'user_role',
        role,
      );

      await prefs.setBool(
        'email_verified',
        user['email_verified'] == true,
      );
    } else {
      // Si no selecciona "Recordarme",
      // eliminamos cualquier sesión persistente anterior.
      await prefs.remove(
        'remember_me',
      );

      await prefs.remove(
        'remembered_email',
      );

      await prefs.remove(
        'is_logged_in',
      );

      await prefs.remove(
        'auth_token',
      );

      await prefs.remove(
        'user_id',
      );

      await prefs.remove(
        'user_full_name',
      );

      await prefs.remove(
        'user_email',
      );

      await prefs.remove(
        'user_role',
      );

      await prefs.remove(
        'email_verified',
      );
    }
  }

  String _formatErrors(
    dynamic errors,
  ) {
    if (errors == null) {
      return 'No fue posible iniciar sesión.';
    }

    if (errors is Map) {
      final messages = <String>[];

      errors.forEach(
        (key, value) {
          if (value is List) {
            messages.add(
              value.join(', '),
            );
          } else {
            messages.add(
              value.toString(),
            );
          }
        },
      );

      if (messages.isEmpty) {
        return 'No fue posible iniciar sesión.';
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

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError
                ? Colors.red
                : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Scaffold(
      backgroundColor:
          colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints:
                const BoxConstraints(
              maxWidth: 400,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                // =========================
                // Header
                // =========================

                Text(
                  'Bienvenido de nuevo',
                  style: theme
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
                  textAlign:
                      TextAlign.center,
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  'Inicia sesión para continuar en WorkNet.',
                  style: theme
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                    color: colorScheme
                        .onSurface
                        .withValues(
                      alpha: 0.6,
                    ),
                  ),
                  textAlign:
                      TextAlign.center,
                ),

                const SizedBox(
                  height: 32,
                ),

                // =========================
                // Social
                // =========================

                Row(
                  children: [
                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _isLoading
                                ? null
                                : () {},
                        icon:
                            const Icon(
                          Icons.public,
                          size: 18,
                        ),
                        label:
                            const Text(
                          'Google',
                        ),
                        style:
                            OutlinedButton
                                .styleFrom(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 16,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 16,
                    ),

                    Expanded(
                      child:
                          OutlinedButton.icon(
                        onPressed:
                            _isLoading
                                ? null
                                : () {},
                        icon:
                            const Icon(
                          Icons
                              .business_center_outlined,
                          size: 18,
                        ),
                        label:
                            const Text(
                          'LinkedIn',
                        ),
                        style:
                            OutlinedButton
                                .styleFrom(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 16,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                // =========================
                // Divider
                // =========================

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color:
                            colorScheme
                                .outline
                                .withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 16,
                      ),
                      child: Text(
                        'O CON TU CORREO',
                        style: theme
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                          color:
                              colorScheme
                                  .onSurface
                                  .withValues(
                            alpha: 0.5,
                          ),
                          fontWeight:
                              FontWeight.bold,
                          letterSpacing:
                              1.2,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Divider(
                        color:
                            colorScheme
                                .outline
                                .withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                // =========================
                // Correo
                // =========================

                Text(
                  'Correo electrónico',
                  style: theme
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                TextField(
                  controller:
                      _emailController,
                  enabled:
                      !_isLoading,
                  keyboardType:
                      TextInputType.emailAddress,
                  textInputAction:
                      TextInputAction.next,
                  decoration:
                      InputDecoration(
                    hintText:
                        'correo@ejemplo.com',
                    prefixIcon:
                        const Icon(
                      LucideIcons.mail,
                      size: 18,
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    filled: true,
                    fillColor:
                        colorScheme.surface,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                // =========================
                // Contraseña
                // =========================

                Text(
                  'Contraseña',
                  style: theme
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                TextField(
                  controller:
                      _passwordController,
                  enabled:
                      !_isLoading,
                  obscureText:
                      _obscurePassword,
                  textInputAction:
                      TextInputAction.done,
                  onSubmitted: (_) {
                    if (!_isLoading) {
                      _login();
                    }
                  },
                  decoration:
                      InputDecoration(
                    hintText:
                        '••••••••••••••••',
                    prefixIcon:
                        const Icon(
                      LucideIcons.lock,
                      size: 18,
                    ),
                    suffixIcon:
                        IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? LucideIcons.eye
                            : LucideIcons.eyeOff,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                              !_obscurePassword;
                        });
                      },
                    ),
                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    filled: true,
                    fillColor:
                        colorScheme.surface,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                // =========================
                // Opciones
                // =========================

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value:
                              _rememberMe,
                          onChanged:
                              _isLoading
                                  ? null
                                  : (value) {
                                      setState(
                                        () {
                                          _rememberMe =
                                              value ??
                                                  false;
                                        },
                                      );
                                    },
                        ),
                        const Text(
                          'Recordarme',
                        ),
                      ],
                    ),

                    TextButton(
                      onPressed:
                          _isLoading
                              ? null
                              : () {
                                  _showMessage(
                                    'La recuperación de contraseña se integrará en HU003.',
                                  );
                                },
                      child:
                          const Text(
                        '¿Olvidaste tu contraseña?',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 32,
                ),

                // =========================
                // Login
                // =========================

                ElevatedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : _login,
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        const Color(
                      0xFF0F62FE,
                    ),
                    disabledBackgroundColor:
                        const Color(
                      0xFF0F62FE,
                    ).withValues(
                      alpha: 0.6,
                    ),
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 16,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Text(
                              'Iniciar sesión',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Icon(
                              LucideIcons
                                  .arrowRight,
                              size: 18,
                            ),
                          ],
                        ),
                ),

                const SizedBox(
                  height: 32,
                ),

                // =========================
                // Footer
                // =========================

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  children: [
                    const Text(
                      '¿No tienes cuenta? ',
                    ),

                    InkWell(
                      onTap:
                          _isLoading
                              ? null
                              : () {
                                  context.go(
                                    '/register',
                                  );
                                },
                      child: Text(
                        'Regístrate gratis',
                        style: TextStyle(
                          color:
                              colorScheme
                                  .primary,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}