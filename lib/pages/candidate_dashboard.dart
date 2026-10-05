import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../components/dashboard_widgets.dart';

import '../components/profile_edit_modal.dart';

class CandidateDashboard extends StatefulWidget {
  const CandidateDashboard({super.key});

  @override
  State<CandidateDashboard> createState() => _CandidateDashboardState();
}

class _CandidateDashboardState extends State<CandidateDashboard> {
  String name = 'Camila Restrepo';
  String role = 'Lead Product Designer & Design Systems';
  String location = 'Medellín, Colombia • Remoto Global';

  void _openSettings() {
    context.push('/settings/candidate');
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = const Color(0xFF0F62FE);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: DashboardHeader(
        title: 'WorkNet',
        onBack: () => context.go('/'),
        onAvatarTap: _openSettings,
        trailing: IconButton(icon: const Icon(LucideIcons.settings, color: Colors.black87), onPressed: _openSettings),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Profile
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: primaryBlue.withOpacity(0.1),
                    child: Icon(LucideIcons.user, size: 40, color: primaryBlue),
                  ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(role, style: const TextStyle(fontSize: 14, color: Color(0xFF0F62FE), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.mapPin, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(location, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _openSettings,
                          icon: const Icon(LucideIcons.edit2, size: 16),
                          label: const Text('Editar Perfil'),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white, elevation: 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(LucideIcons.download, size: 16),
                          label: const Text('Descargar CV'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // Optimization Profile
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(LucideIcons.rocket, color: primaryBlue, size: 18),
                                const SizedBox(width: 8),
                                const Text('Optimización de Perfil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const Text('88%', style: TextStyle(color: Color(0xFF0F62FE), fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const AnimatedProgressBar(value: 0.88),
                        const SizedBox(height: 16),
                        _buildTaskItem('Portafolio web verificado', true),
                        _buildTaskItem('Test de Figma Tokens', true),
                        _buildTaskItem('Añadir video presentación', false, actionText: 'Subir'),
                      ],
                    ),
                  ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
                  const SizedBox(height: 24),

                  const SectionTitle(title: 'Resumen Profesional').animate().fade(delay: 300.ms),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Diseñadora de Producto con más de 7 años de experiencia creando y escalando sistemas de diseño multiplataforma en entornos fintech y e-commerce.', style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey.shade700)),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildSkillChip('Figma Tokens'),
                            _buildSkillChip('Design Systems'),
                            _buildSkillChip('React Basics'),
                            _buildSkillChip('User Research'),
                          ],
                        )
                      ],
                    ),
                  ).animate().fade(delay: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 24),

                  const SectionTitle(title: 'Experiencia Laboral').animate().fade(delay: 500.ms),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        _buildExperience('Staff Design Systems', 'Mercado Libre', 'Mar 2023 - Presente', true),
                        const Divider(height: 32),
                        _buildExperience('Senior Product Designer', 'Nubank', 'Jan 2021 - Feb 2023', false),
                      ],
                    ),
                  ).animate().fade(delay: 600.ms).slideY(begin: 0.1),
                  const SizedBox(height: 40),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(String text, bool isDone, {String? actionText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(isDone ? LucideIcons.checkCircle2 : LucideIcons.circle, color: isDone ? Colors.green : Colors.grey.shade400, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: isDone ? Colors.black87 : Colors.grey.shade700))),
          if (!isDone && actionText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF0F62FE), borderRadius: BorderRadius.circular(8)),
              child: Text(actionText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            )
          else if (isDone)
            const Text('+10 pts', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF0F62FE).withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: Text(label, style: const TextStyle(color: Color(0xFF0F62FE), fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildExperience(String role, String company, String date, bool isCurrent) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: isCurrent ? const Color(0xFF0F62FE) : Colors.grey.shade300, shape: BoxShape.circle)),
            if (isCurrent) Container(width: 2, height: 40, color: Colors.grey.shade200),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(company, style: TextStyle(color: const Color(0xFF0F62FE), fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
        )
      ],
    );
  }
}
