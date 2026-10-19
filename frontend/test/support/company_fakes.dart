Map<String, dynamic> companyData({
  String state = 'pending',
  bool submitted = false,
  int? id = 1,
  int version = 2,
}) => {
  'id': id,
  'state': state,
  'submitted': submitted,
  'version': version,
  'legal_name': 'Empresa ficticia QA',
  'tax_id': '900111222-3',
  'sector': 'Tecnología',
  'location': 'Pasto',
  'contact_email': 'contacto@worknet.test',
  'description': 'Organización ficticia para QA',
  'rejection_reason': state == 'rejected' ? 'Corrige la razón social.' : '',
  'website': '',
  'social_links': [],
  'has_logo': false,
};
Map<String, dynamic> companySummary() => {
  'metrics': {'active_offers': 2, 'closed_offers': 1, 'applications': 3},
  'notifications': [],
  'recent_applications': [],
};
Map<String, dynamic> adminSummary() => {
  'metrics': {'candidates': 4, 'companies': 2, 'pending_companies': 1},
  'notifications': [
    {'title': 'Nueva solicitud de empresa: Empresa ficticia QA'},
  ],
  'recent_events': [
    {'profile__legal_name': 'Empresa ficticia QA', 'action': 'submitted'},
  ],
};
