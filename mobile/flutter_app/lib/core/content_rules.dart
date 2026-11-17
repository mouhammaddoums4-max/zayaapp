import 'phone_mask.dart';

final RegExp _email = RegExp(r'[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}', caseSensitive: false);
final RegExp _messagingLink = RegExp(r'(wa\.me|whatsapp\.com|t\.me|telegram\.me|m\.me)/', caseSensitive: false);

/// Coordonnées interdites dans la Communauté (CDC V2.3 §2.3 et §2.6) : numéro de téléphone, e-mail,
/// lien de messagerie externe. Les montants suivis d'une devise ne sont pas des numéros.
/// Même règle que la fonction serveur `contains_contact_details`, qui reste la référence.
bool containsContactDetails(String text) =>
    _email.hasMatch(text) || _messagingLink.hasMatch(text) || containsPhone(text);
