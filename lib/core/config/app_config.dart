// lib/core/config/app_config.dart

class AppConfig {
  static const String odooBaseUrl = 'https://elthub-preproduzione3.odoo.com';
  static const String odooDb = 'elthub-preproduzione3'; // su SaaS spesso è il nome del database/istanza
  static const String odooUsername = 'odooadmin@elthub.it';
  static const String odooPassword = '4dm1nasdzxc2121!';

  // Modelli (metti qui quelli reali che vedi in Studio)
  static const String visitModel = 'x_visite_esterne';
  static const String badgeModel = 'x_badge'; // oppure 'x_studio_badge'
  static const String visitorModel = 'x_visitatori';

}
