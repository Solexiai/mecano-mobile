// Écrit les pages publiques lisibles par Google et les IA, et /llms.txt, dans
// le dossier du build web (Daniel, 2026-11-10). Lancé par
// scripts/vercel_build.sh après `flutter build web` :
//
//   dart run tool/build_seo_pages.dart build/web
//
// Le contenu vient de lib/seo/seo_pages.dart et lib/content/faq_content.dart ;
// vercel.json sert chaque fichier /seo/... à l'adresse publique de la page.
import 'dart:io';

import 'package:movik_connect/seo/seo_html.dart';

void main(List<String> args) {
  final out = Directory(args.isEmpty ? 'build/web' : args.first);
  final index = File('${out.path}/index.html');
  if (!index.existsSync()) {
    stderr.writeln('ERREUR : ${index.path} introuvable (lancer flutter build web avant).');
    exit(1);
  }
  final pages = renderAllSeoPages(index.readAsStringSync());
  for (final entry in pages.entries) {
    final file = File('${out.path}${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }
  File('${out.path}/llms.txt').writeAsStringSync(renderLlmsTxt());
  stdout.writeln('Pages SEO : ${pages.length} pages + llms.txt écrites dans ${out.path}.');
}
