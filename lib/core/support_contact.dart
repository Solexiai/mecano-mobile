/// Courriel de support affiché aux clients et aux chauffeurs (page Contact,
/// recherche de chauffeur, page Granby). Décision de Daniel du 28 oct. 2026 :
/// adresse personnelle surveillée en attendant une boîte d'entreprise.
/// Une seule source : changer ici change partout (tests compris).
const String kSupportEmail = 'dantang3030@gmail.com';

/// Lien `mailto:` vers le support.
final Uri kSupportMailto = Uri(scheme: 'mailto', path: kSupportEmail);
