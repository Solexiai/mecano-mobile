# Échecs conservés — P2-G-02

Base : da3f1d459c3205e55aec3f1d972aab45b4fa7423, 11 octobre 2026.

## Avant correction (before.jsonl, 0/35/0)

Test : S quote fr step=1 layout=(375.0, 812.0, 1.0).
Attendu : chaîne contenant « 1 234,50 $ CA ».
Observé dans le vrai widget : « 1234.50 CAD », « 1000.00 CAD », « Distance routière : 10.0 km ».
Échec d'assertion : delivery_quote_display_test.dart:90 dans la version archivée TEST_REPRODUCTION_AVANT.dart.txt.

Test : S absent and invalid display values fr are not invented.
Exception exacte :
```text
type 'Null' is not a subtype of type 'num' in type cast
#0 _DeliveryRequestFlowScreenState._quoteSummary.money
   package:movik_connect/screens/delivery/delivery_request_flow_screen.dart:1542:38
#1 _DeliveryRequestFlowScreenState._quoteSummary
   package:movik_connect/screens/delivery/delivery_request_flow_screen.dart:1567:17
#2 _DeliveryRequestFlowScreenState._price
   package:movik_connect/screens/delivery/delivery_request_flow_screen.dart:1466:61
```

Les 35 noms des tests échoués sont conservés dans RESULTATS_TESTS.json. Le journal brut intégral reste localement dans ce dossier ; son ancien décodage console Windows n'est pas retouché.

## Après première correction (after-1.jsonl, 35/6/0)

Les six échecs concernent seulement le texte à 200 %, deux étapes × trois langues.

Extrait exact du premier :
```text
A RenderFlex overflowed by 80 pixels on the right.
Row:file:///C:/Users/Utilisateur/movik-gps-history-fix-20261009/lib/screens/delivery/delivery_request_flow_screen.dart:1587:28
constraints: BoxConstraints(0.0<=w<=287.0, 0.0<=h<=Infinity)
Expected: a value less than or equal to <375.1>
Actual: <411.25>
1 000,00 $ CA
```

Le Row rigide de la ventilation est remplacé par un Wrap contraint. Aucun montant ni taille de police diminué pour cacher l'erreur.

## Résultats suivants

after-2 : 47 réussis / 0 échec / 0 ignoré.
regression : 97 réussis / 0 échec / 0 ignoré.
Les exécutions initiales restent des échecs historiques ; elles ne sont pas additionnées au bilan final.
