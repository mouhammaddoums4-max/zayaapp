/// Détection et masquage des numéros de téléphone dans les messages (V6.3 §34.1).
/// Le numéro est masqué par défaut chez le destinataire et révélé après avertissement.
library;

class MessageSegment {
  const MessageSegment(this.text, {this.isPhone = false});
  final String text;
  final bool isPhone;
}

// Suite de 8 à 15 chiffres, séparés éventuellement par espace, point ou tiret, avec préfixe + ou 00 facultatif.
// Les barres obliques ne sont pas des séparateurs : une date (12/05/2026) n'est donc pas reconnue.
final RegExp _candidate = RegExp(r'(?<![\w/])(?:\+|00)?\d(?:[ .\-]?\d){7,14}(?![\w/])');
final RegExp _currencyAfter = RegExp(r'^\s*(gnf|fg|francs?|fcfa|cfa|euros?|usd|dollars?|€|\$)', caseSensitive: false);
final RegExp _referenceBefore =
    RegExp(r'(commande|référence|reference|réf|ref|ticket|dossier|n°)\s*[:#]?\s*$', caseSensitive: false);

List<MessageSegment> splitPhones(String text) {
  final segments = <MessageSegment>[];
  var cursor = 0;
  for (final m in _candidate.allMatches(text)) {
    final raw = m.group(0)!;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8 || digits.length > 15) continue;
    // Montants (« 15 000 000 GNF ») et références de commande ne sont pas des numéros de téléphone.
    if (_currencyAfter.hasMatch(text.substring(m.end))) continue;
    if (_referenceBefore.hasMatch(text.substring(0, m.start))) continue;
    if (m.start > cursor) segments.add(MessageSegment(text.substring(cursor, m.start)));
    segments.add(MessageSegment(raw, isPhone: true));
    cursor = m.end;
  }
  if (cursor < text.length) segments.add(MessageSegment(text.substring(cursor)));
  return segments;
}

bool containsPhone(String text) => splitPhones(text).any((s) => s.isPhone);

/// « +224 622 11 22 33 » → « +224 ••• •• •• •• » ; sans indicatif → « ••• •• •• •• ».
String maskPhone(String raw) {
  final trimmed = raw.trim();
  final prefix = RegExp(r'^(\+\d{1,3}|00\d{1,3})').firstMatch(trimmed)?.group(0);
  const masked = '••• •• •• ••';
  return prefix == null ? masked : '$prefix $masked';
}
