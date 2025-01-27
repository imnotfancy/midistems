import 'dart:math';

/// A collection of random domain + tagline combos from the .lol multiverse.
final List<String> domainTaglines = [
  'Disclosure.lol => "We disclose everything except the important parts"',
  'Whistleblower.lol => "We blow whistles—loudly—so you can\'t ignore it"',
  'NHI.lol => "Non-Human Intelligence? Sure, we\'ll try anything once"',
  'NRK.lol => "Norwegian Ridiculous Komedy, streaming 24/7"',
  'Sticknation.lol => "We\'re building a nation. Out of sticks. Duh"',
  'elonwyd.lol => "The world\'s biggest question: why, Elon, why?"'
];

/// Extract domain from a tagline.
String getDomain(String tagline) {
  return tagline.split(' => ').first;
}

/// Extract message from a tagline.
String getMessage(String tagline) {
  return tagline.split(' => ').last.replaceAll('"', '');
}

/// Fetch a random domain + tagline string from [domainTaglines].
String getRandomLolTagline() {
  final random = Random();
  return domainTaglines[random.nextInt(domainTaglines.length)];
}