import 'phone_mask.dart';

final RegExp _email = RegExp(r'[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)*\.[a-z]{2,}', caseSensitive: false);
final RegExp _messagingLink = RegExp(r'(wa\.me|whatsapp\.com|t\.me|telegram\.me|m\.me)/', caseSensitive: false);

/// Coordonnées interdites dans la Communauté (CDC V2.3 §2.3 et §2.6) : numéro de téléphone, e-mail,
/// lien de messagerie externe. Les montants suivis d'une devise ne sont pas des numéros.
/// Même règle que la fonction serveur `contains_contact_details`, qui reste la référence.
bool containsContactDetails(String text) =>
    _email.hasMatch(text) || _messagingLink.hasMatch(text) || containsPhone(text);

// Début d'un mot qui n'est pas la suite d'un e-mail, d'un domaine ou d'un mot (comme côté serveur).
const String _start = r'(^|[^a-z0-9@._-])';
final List<RegExp> _links = [
  RegExp(r'[a-z][a-z0-9+.-]{1,15}://', caseSensitive: false),
  RegExp('${_start}www\\s*\\.', caseSensitive: false),
  RegExp(
      '$_start[a-z0-9-]+(\\.[a-z0-9-]+)*\\.(com|net|org|info|biz|app|dev|link|site|online|shop|store|xyz|top|live|click|io)\\b',
      caseSensitive: false),
  RegExp('$_start[a-z0-9-]+\\s+\\.\\s*(com|net|org)\\b', caseSensitive: false),
  RegExp(
      '$_start(bit\\.ly|goo\\.gl|tinyurl|t\\.co|cutt\\.ly|rb\\.gy|is\\.gd|ow\\.ly|shorturl\\.at|wa\\.me|t\\.me|m\\.me)\\b',
      caseSensitive: false),
  RegExp('$_start[a-z0-9-]+(\\.[a-z0-9-]+)*\\.[a-z]{2,}/\\S', caseSensitive: false),
  RegExp(r'\b(point|dot)\s*(com|net|org)\b', caseSensitive: false),
];

/// Liens interdits dans la messagerie (demande du propriétaire, 18/11/2026) : adresse avec protocole, « www. »,
/// domaine avec une extension courante, raccourcisseur, domaine suivi d'un chemin, « site point com ». Une adresse
/// e-mail n'en est pas un, ni une fin de phrase sans espace (« ok.Ma sœur »).
/// Même règle que la fonction serveur `contains_link` (migration 0051), qui reste la référence.
bool containsLink(String text) => _links.any((r) => r.hasMatch(text));
