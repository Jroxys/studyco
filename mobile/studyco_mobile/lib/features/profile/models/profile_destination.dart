enum ProfileDestination {
  edit('Profili Düzenle'),
  tokens('Token Yükle'),
  posts('İlanlarım'),
  applications('Başvurularım'),
  incomingApplications('Gelen Başvurular'),
  reviews('Değerlendirmelerim'),
  settings('Ayarlar'),
  logout('Çıkış Yap');

  const ProfileDestination(this.label);
  final String label;
}
