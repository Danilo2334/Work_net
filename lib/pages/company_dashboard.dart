import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../components/dashboard_widgets.dart';

import '../components/profile_edit_modal.dart';

class CompanyDashboard extends StatefulWidget {
  const CompanyDashboard({super.key});

  @override
  State<CompanyDashboard> createState() => _CompanyDashboardState();
}

class _CompanyDashboardState extends State<CompanyDashboard> {
  String companyName = 'Mercado Pago';
  String subtitle = 'FinTech Core • Partner Oficial';

  void _openSettings() {
    context.push('/settings/company');
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = const Color(0xFF0F62FE);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: DashboardHeader(
        title: 'Ats Dashboard', 
        onBack: () => context.go('/'),
        onAvatarTap: _openSettings,
        trailing: IconButton(icon: const Icon(LucideIcons.settings, color: Colors.black87), onPressed: _openSettings),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Company Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: Icon(LucideIcons.shieldCheck, color: primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Verificada 4.9', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(LucideIcons.edit3, size: 16, color: Colors.grey),
                                  onPressed: _openSettings,
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                )
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(LucideIcons.plusCircle, size: 16),
                          label: const Text('Publicar Vacante'),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(LucideIcons.users, size: 16),
                          label: const Text('Equipo (8)'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ).animate().fade().slideY(begin: 0.1),
            const SizedBox(height: 24),

            // IA Credits
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  Icon(LucideIcons.sparkles, color: primaryBlue, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Créditos IA Sourcing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('Reinicio en 12 días', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                  const Text('8,450', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F62FE))),
                  const Text(' / 10,000', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ).animate().fade(delay: 100.ms),
            const SizedBox(height: 24),

            const SectionTitle(title: 'Métricas de Selección'),
            Row(
              children: [
                Expanded(child: KPICard(title: 'En Pipeline', value: '342', trendText: '+18%', icon: LucideIcons.users)),
                const SizedBox(width: 12),
                Expanded(child: KPICard(title: 'Time to Hire', value: '14d', trendText: '-4d vs SLA', trendColor: Colors.green, icon: LucideIcons.clock)),
              ],
            ).animate().fade(delay: 200.ms).slideX(begin: 0.1),
            const SizedBox(height: 24),

            const SectionTitle(title: 'Procesos Activos'),
            _buildProcessCard('Senior Product Designer', '45 postulantes', [28, 13, 3, 1]).animate().fade(delay: 300.ms).slideY(begin: 0.1),
            const SizedBox(height: 12),
            _buildProcessCard('Lead Backend Engineer', '68 postulantes', [41, 5, 2, 0]).animate().fade(delay: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessCard(String title, String subtitle, List<int> pipeline) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildPipelineStage('Screening', pipeline[0], const Color(0xFFEEF2FF)),
              const SizedBox(width: 4),
              _buildPipelineStage('Prueba', pipeline[1], const Color(0xFFE0E7FF)),
              const SizedBox(width: 4),
              _buildPipelineStage('Entrevista', pipeline[2], const Color(0xFFC7D2FE)),
              const SizedBox(width: 4),
              _buildPipelineStage('Oferta', pipeline[3], const Color(0xFFA5B4FC)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPipelineStage(String name, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo.shade900)),
            Text(name, style: TextStyle(fontSize: 9, color: Colors.indigo.shade700)),
          ],
        ),
      ),
    );
  }
}
