import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  final String role; // 'candidate', 'company', 'admin'
  const SettingsPage({super.key, required this.role});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final primaryBlue = const Color(0xFF0F62FE);
  bool notifications = true;
  bool darkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader('Datos Personales'),
                _buildCard([
                  _buildTextField('Nombre Completo', 'Ej. Camila Restrepo'),
                  _buildTextField('Correo Electrónico', 'correo@ejemplo.com'),
                  if (widget.role == 'company') _buildTextField('Nombre de la Empresa', 'Ej. Mercado Pago'),
                ]),

                if (widget.role == 'candidate') ...[
                  _buildSectionHeader('Foto y Perfil Público'),
                  _buildCard([
                    Row(
                      children: [
                        CircleAvatar(radius: 30, backgroundColor: primaryBlue.withOpacity(0.1), child: Icon(LucideIcons.camera, color: primaryBlue)),
                        const SizedBox(width: 16),
                        OutlinedButton(onPressed: () {}, child: const Text('Cambiar Foto')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Titular Profesional', 'Ej. Lead Product Designer'),
                    _buildTextField('Biografía', 'Describe tu perfil brevemente...', maxLines: 3),
                  ]),
                  
                  _buildSectionHeader('Educación y Experiencia'),
                  _buildCard([
                    _buildListTile(LucideIcons.briefcase, 'Experiencia Laboral', '2 puestos añadidos', onTap: () {}),
                    _buildListTile(LucideIcons.graduationCap, 'Educación', '1 título añadido', onTap: () {}),
                  ]),

                  _buildSectionHeader('Habilidades e Idiomas'),
                  _buildCard([
                    _buildListTile(LucideIcons.code, 'Habilidades Técnicas', 'Figma, React, UI/UX', onTap: () {}),
                    _buildListTile(LucideIcons.languages, 'Idiomas', 'Inglés (C1), Español (Nativo)', onTap: () {}),
                  ]),
                ],

                if (widget.role == 'company') ...[
                  _buildSectionHeader('Datos de la Empresa'),
                  _buildCard([
                    _buildTextField('Industria / Sector', 'Ej. FinTech'),
                    _buildTextField('Sitio Web', 'https://...'),
                  ]),
                ],

                _buildSectionHeader('Seguridad y Contraseña'),
                _buildCard([
                  _buildTextField('Contraseña Actual', '••••••••', obscure: true),
                  _buildTextField('Nueva Contraseña', '••••••••', obscure: true),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, foregroundColor: Colors.white),
                    child: const Text('Actualizar Contraseña'),
                  ),
                ]),

                _buildSectionHeader('Preferencias'),
                _buildCard([
                  SwitchListTile(
                    title: const Text('Notificaciones Push', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Recibe alertas de nuevos matches.', style: TextStyle(fontSize: 12)),
                    value: notifications,
                    activeColor: primaryBlue,
                    onChanged: (val) => setState(() => notifications = val),
                  ),
                  SwitchListTile(
                    title: const Text('Modo Oscuro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    value: darkMode,
                    activeColor: primaryBlue,
                    onChanged: (val) => setState(() => darkMode = val),
                  ),
                ]),

                _buildSectionHeader('Zona de Peligro', color: Colors.red),
                _buildCard([
                  const Text('Una vez que elimines tu cuenta, no hay vuelta atrás. Por favor, asegúrate.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.trash2, size: 16),
                    label: const Text('Eliminar Cuenta'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  ),
                ]),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 8),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {bool obscure = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 6),
          TextField(
            obscureText: obscure,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: primaryBlue, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(LucideIcons.chevronRight, size: 16),
      onTap: onTap,
    );
  }
}
