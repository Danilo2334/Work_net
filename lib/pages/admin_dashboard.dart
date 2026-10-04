import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../components/dashboard_widgets.dart';

import '../components/profile_edit_modal.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String adminName = 'Administrador Global';
  String adminEmail = 'admin@worknet.ai';

  void _openSettings() {
    context.push('/settings/admin');
  }

  @override
  Widget build(BuildContext context) {
    final primaryBlue = const Color(0xFF0F62FE);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: DashboardHeader(
        title: 'Admin Metrics',
        onBack: () => context.go('/'),
        onAvatarTap: _openSettings,
        trailing: IconButton(icon: const Icon(LucideIcons.settings, color: Colors.black87), onPressed: _openSettings),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    const Text('Prod v2.4 • 99.98% uptime', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: Icon(LucideIcons.download, size: 14, color: primaryBlue),
                  label: Text('Auditoría', style: TextStyle(color: primaryBlue, fontSize: 12)),
                )
              ],
            ).animate().fade().slideY(begin: -0.1),
            const SizedBox(height: 16),
            
            // Period Toggle
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  _buildPeriodTab('Hoy', false),
                  _buildPeriodTab('7 días', true, primaryBlue),
                  _buildPeriodTab('Este Mes', false),
                  _buildPeriodTab('Q3', false),
                ],
              ),
            ).animate().fade(delay: 100.ms),
            const SizedBox(height: 24),

            SectionTitle(
              title: 'KPIs de Administración',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text('En tiempo real', style: TextStyle(color: primaryBlue, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ).animate().fade(delay: 200.ms),

            // Grid KPIs
            Row(
              children: [
                Expanded(child: KPICard(title: 'Usuarios Totales', value: '128,450', icon: LucideIcons.users, trendText: '+8.4%', customBody: Column(children: [_buildKpiSub('Candidatos', '112.2k'), _buildKpiSub('Empresas', '16.2k')]))),
                const SizedBox(width: 12),
                Expanded(child: KPICard(title: 'MRR Activo', value: '\$248.5k', icon: LucideIcons.banknote, trendText: '+14.2% MoM', customBody: Column(children: [_buildKpiSub('ARR', '\$2.98M', isBold: true), _buildKpiSub('Churn', '0.82%', color: Colors.green)]))),
              ],
            ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: KPICard(title: 'Vacantes Activas', value: '4,890', icon: LucideIcons.briefcase, trendText: '98.2% LLM SafeMatch', trendColor: Colors.green, customBody: const AnimatedProgressBar(value: 0.98, color: Colors.green))),
                const SizedBox(width: 12),
                Expanded(child: KPICard(title: 'Postulaciones', value: '1,420', icon: LucideIcons.checkCircle, trendText: '+22.1% mes', customBody: const Text('Prom. cierre: 8.4 días', style: TextStyle(fontSize: 11, color: Colors.grey)))),
              ],
            ).animate().fade(delay: 400.ms).slideY(begin: 0.1),
            const SizedBox(height: 24),

            // Validacion de empresas
            SectionTitle(
              title: 'Validación de Empresas',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Text('4 Urgentes', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ).animate().fade(delay: 500.ms),

            _buildValidationCard('Nexura Logistics SAS', 'Senior Data Architect', true).animate().fade(delay: 600.ms).slideX(begin: 0.1),
            const SizedBox(height: 12),
            _buildValidationCard('Vektor Fintech Global', 'Staff Blockchain Lead', false).animate().fade(delay: 700.ms).slideX(begin: 0.1),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(String text, bool active, [Color? color]) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
        ),
        child: Center(
          child: Text(text, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: active ? color : Colors.grey.shade600)),
        ),
      ),
    );
  }

  Widget _buildKpiSub(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildValidationCard(String company, String position, bool isApproved) {
    final primaryBlue = const Color(0xFF0F62FE);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isApproved ? primaryBlue.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                child: Text(company.substring(0, 2), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isApproved ? primaryBlue : Colors.red)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(company, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 4),
                        Icon(isApproved ? LucideIcons.checkCircle2 : LucideIcons.alertTriangle, size: 14, color: isApproved ? Colors.green : Colors.red),
                      ],
                    ),
                    Text(position, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isApproved) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
              child: const Text('Requiere cotejar RFC SAT y validación biométrica.', style: TextStyle(fontSize: 11, color: Colors.black87)),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              if (isApproved) Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Rechazar'))),
              if (isApproved) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: isApproved ? primaryBlue : const Color(0xFF4F46E5), foregroundColor: Colors.white, elevation: 0),
                  child: Text(isApproved ? 'Aprobar Oferta' : 'Abrir Expediente KYC'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
