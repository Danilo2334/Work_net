import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isCandidate = true;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  String _password = '';

  int get _strengthScore {
    if (_password.isEmpty) return 0;
    int score = 0;
    if (_password.length >= 8) score++;
    if (_password.contains(RegExp(r'[A-Z]'))) score++;
    if (_password.contains(RegExp(r'[a-z]'))) score++;
    if (_password.contains(RegExp(r'[0-9!@#\$&*~._-]'))) score++;
    return score;
  }

  String get _strengthText {
    switch (_strengthScore) {
      case 0: return '';
      case 1: return 'Débil';
      case 2: return 'Regular';
      case 3: return 'Buena';
      case 4: return 'Fuerte';
      default: return '';
    }
  }

  Color get _strengthColor {
    switch (_strengthScore) {
      case 1: return Colors.red;
      case 2: return Colors.orange;
      case 3: return Colors.yellow.shade700;
      case 4: return Colors.green;
      default: return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryBlue = const Color(0xFF0F62FE);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black87),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: primaryBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.work, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'Work_net',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Center(
            child: Text(
              'Registro',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            backgroundColor: primaryBlue,
            radius: 14,
            child: const Icon(LucideIcons.user, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Crea tu cuenta',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Únete a la plataforma líder para talento y empresas de alto impacto',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
            const SizedBox(height: 24),

            // Toggle Soy Candidato / Soy Empresa
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCandidate = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isCandidate ? primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.user, size: 18, color: _isCandidate ? Colors.white : Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Soy Candidato',
                              style: TextStyle(
                                color: _isCandidate ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isCandidate = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isCandidate ? primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.building, size: 18, color: !_isCandidate ? Colors.white : Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Soy Empresa',
                              style: TextStyle(
                                color: !_isCandidate ? Colors.white : Colors.grey.shade700,
                                fontWeight: FontWeight.bold,
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

            // Social Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.chrome, size: 18, color: Colors.red), 
                    label: const Text('Google', style: TextStyle(color: Colors.black87)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.linkedin, size: 18, color: Color(0xFF0A66C2)),
                    label: const Text('LinkedIn', style: TextStyle(color: Colors.black87)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'O COMPLETA TUS DATOS',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 24),

            // Form Fields
            _buildLabel('Nombre completo'),
            TextField(
              decoration: _inputDecoration(
                hint: 'Ej. Mariana Valenzuela',
                icon: LucideIcons.user,
              ),
            ),
            const SizedBox(height: 16),

            _buildLabel('Correo electrónico profesional'),
            TextField(
              decoration: _inputDecoration(
                hint: 'mariana.v@techlead.io',
                icon: LucideIcons.mail,
                suffixIcon: const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 18),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('Contraseña'),
                if (_password.isNotEmpty)
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: _strengthColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Seguridad: $_strengthText', style: TextStyle(color: _strengthColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              obscureText: _obscurePassword,
              onChanged: (val) => setState(() => _password = val),
              decoration: _inputDecoration(
                hint: '••••••••••••',
                icon: LucideIcons.lock,
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff, size: 18, color: Colors.grey.shade600),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Password strength bars
            Row(
              children: [
                Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _strengthScore >= 1 ? _strengthColor : Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(width: 4),
                Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _strengthScore >= 2 ? _strengthColor : Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(width: 4),
                Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _strengthScore >= 3 ? _strengthColor : Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(width: 4),
                Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _strengthScore >= 4 ? _strengthColor : Colors.grey.shade200, borderRadius: BorderRadius.circular(2)))),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _acceptedTerms,
                    onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                    activeColor: primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.5),
                      children: [
                        const TextSpan(text: 'Acepto los '),
                        TextSpan(text: 'Términos de Servicio', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600)),
                        const TextSpan(text: ' y la '),
                        TextSpan(text: 'Política de Privacidad', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600)),
                        const TextSpan(text: ' de WorkNet.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Registrarme gratis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(LucideIcons.arrowRight, color: Colors.white, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Badge Bottom
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Icon(LucideIcons.award, color: primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('+85,000 candidatos calificados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('12 días promedio de colocación laboral', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('¿Ya tienes cuenta? ', style: TextStyle(color: Colors.grey.shade700)),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text('Inicia sesión', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF0F62FE)),
      ),
    );
  }
}
