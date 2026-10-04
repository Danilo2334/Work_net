import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.0, 0.05), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        },
        child: _buildBodyForIndex(_currentIndex),
      ),
      bottomNavigationBar: _buildMacOsStyleBottomNav(),
    );
  }

  Widget _buildBodyForIndex(int index) {
    switch (index) {
      case 0:
        return const _HomeTabContent(key: ValueKey('home'));
      case 1:
        return const Center(key: ValueKey('jobs'), child: Text('Sección de Empleos'));
      case 2:
        return const Center(key: ValueKey('companies'), child: Text('Sección de Empresas'));
      case 3:
        return const Center(key: ValueKey('community'), child: Text('Sección de Comunidad'));
      default:
        return const _HomeTabContent(key: ValueKey('home'));
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final primaryBlue = const Color(0xFF0F62FE);
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.work, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Text('Work', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)),
          const Text('_net', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F62FE), fontSize: 18)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text('Ingresar', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
        ),
        IconButton(icon: const Icon(LucideIcons.menu, color: Colors.black87), onPressed: () {}),
        Padding(
          padding: const EdgeInsets.only(right: 16.0, left: 8.0),
          child: CircleAvatar(
            backgroundColor: primaryBlue,
            radius: 16,
            child: const Icon(LucideIcons.user, color: Colors.white, size: 18),
          ),
        )
      ],
    );
  }

  Widget _buildMacOsStyleBottomNav() {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedNavItem(
            icon: LucideIcons.compass,
            label: 'Explorar',
            isSelected: _currentIndex == 0,
            onTap: () => setState(() => _currentIndex = 0),
          ),
          _AnimatedNavItem(
            icon: LucideIcons.briefcase,
            label: 'Empleos',
            isSelected: _currentIndex == 1,
            onTap: () => setState(() => _currentIndex = 1),
          ),
          _AnimatedNavItem(
            icon: LucideIcons.building2,
            label: 'Empresas',
            isSelected: _currentIndex == 2,
            onTap: () => setState(() => _currentIndex = 2),
          ),
          _AnimatedNavItem(
            icon: LucideIcons.messageSquare,
            label: 'Comunidad',
            isSelected: _currentIndex == 3,
            onTap: () => setState(() => _currentIndex = 3),
          ),
        ],
      ),
    );
  }
}

class _AnimatedNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = const Color(0xFF0F62FE);
    final color = widget.isSelected ? primaryBlue : Colors.grey.shade500;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedScale(
          // Efecto de magnificación macOS-style al hacer hover
          scale: _isHovered ? 1.25 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: ScaleTransition(
            // Efecto de 'presionar' al hacer click
            scale: _scaleAnimation,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isSelected ? primaryBlue.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: color, size: 22),
                  if (widget.isSelected) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _HomeTabContent extends StatefulWidget {
  const _HomeTabContent({super.key});

  @override
  State<_HomeTabContent> createState() => _HomeTabContentState();
}

class _HomeTabContentState extends State<_HomeTabContent> {
  bool _isCandidate = true;

  @override
  Widget build(BuildContext context) {
    final primaryBlue = const Color(0xFF0F62FE);
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.sparkles, color: primaryBlue, size: 14),
                  const SizedBox(width: 6),
                  Text('Reclutamiento Inteligente con IA', style: TextStyle(color: primaryBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Headline
            const Text('El futuro del empleo.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.1, color: Colors.black87)),
            Text('Simple. Inteligente.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.1, color: primaryBlue)),
            const SizedBox(height: 16),
            Text(
              'Conectamos talento tech de alto impacto con las mejores empresas globales mediante algoritmos de compatibilidad neural.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 24),

            // Toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCandidate = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _isCandidate ? primaryBlue : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.user, size: 18, color: _isCandidate ? Colors.white : Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Text('Soy Candidato', style: TextStyle(color: _isCandidate ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCandidate = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: !_isCandidate ? primaryBlue : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.building, size: 18, color: !_isCandidate ? Colors.white : Colors.grey.shade700),
                          const SizedBox(width: 8),
                          Text('Soy Empresa', style: TextStyle(color: !_isCandidate ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(LucideIcons.search, color: Colors.grey.shade400, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar vacantes, roles o skills...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.slidersHorizontal, color: Colors.white, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('+15k', 'Vacantes', primaryBlue),
                _buildStatCard('94%', 'Tasa Match', Colors.green),
                _buildStatCard('+2.4k', 'Empresas', primaryBlue),
              ],
            ),
            const SizedBox(height: 32),

            // Algoritmo Neural Live Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: primaryBlue.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.brainCircuit, color: primaryBlue, size: 18),
                          const SizedBox(width: 8),
                          Text('ALGORITMO NEURAL LIVE', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Text('98% Match', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade200,
                          child: Icon(LucideIcons.user, color: Colors.grey.shade500, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Alex Saldaña', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Icon(LucideIcons.badgeCheck, color: primaryBlue, size: 16),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Senior Full Stack • Flutter & Node', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Afinidad con: ', style: TextStyle(fontSize: 12)),
                      const Text('Senior Mobile Lead en Nubank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const Spacer(),
                      const Text('Excelente', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 0.98),
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value, 
                        backgroundColor: Colors.grey.shade200, 
                        color: Colors.green, 
                        borderRadius: BorderRadius.circular(4), 
                        minHeight: 6
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip('Architecture CI/CD'),
                      _buildChip('State Management'),
                      _buildChip('Remote USD'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Center(child: Text('EMPRESAS LÍDERES CONTRATANDO ACTIVAMENTE', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1))),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCompanyChip(LucideIcons.wallet, 'Nubank', primaryBlue),
                  const SizedBox(width: 12),
                  _buildCompanyChip(LucideIcons.truck, 'Mercado Libre', Colors.blue),
                  const SizedBox(width: 12),
                  _buildCompanyChip(LucideIcons.bike, 'Rappi', Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 40),

            const Text('Diseñado para la velocidad del talento', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text('Sin formularios redundantes ni procesos opacos.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 24),

            _buildFeatureCard(LucideIcons.shieldCheck, 'Ofertas y Salarios Verificados', 'Rangos salariales transparentes en USD o moneda local antes de postularte.', primaryBlue.withOpacity(0.1), primaryBlue),
            const SizedBox(height: 16),
            _buildFeatureCard(LucideIcons.zap, 'Postulaciones en 1 Click', 'Sincroniza tu perfil de desarrollador o diseñador y recibe feedback en menos de 48 horas.', const Color(0xFFE0E7FF), const Color(0xFF6366F1)),
            const SizedBox(height: 16),
            _buildFeatureCard(LucideIcons.cpu, 'Filtros IA de Compatibilidad', 'Evaluamos tu stack técnico real y aspiraciones para evitar entrevistas sin sentido.', const Color(0xFFD1FAE5), const Color(0xFF10B981)),
            const SizedBox(height: 60),

            // Call to action bottom
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: primaryBlue, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryBlue.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]),
                child: const Icon(LucideIcons.rocket, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 24),
            const Text('¿Listo para dar el siguiente salto?', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('Crea tu perfil gratuito en 2 minutos y accede a propuestas exclusivas de alto valor.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Comenzar Ahora Gratis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(LucideIcons.arrowRight, color: Colors.white, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('¿Ya tienes cuenta? ', style: TextStyle(color: Colors.black54)),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: Text('Iniciar Sesión', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildCompanyChip(IconData icon, String name, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc, Color bgColor, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
