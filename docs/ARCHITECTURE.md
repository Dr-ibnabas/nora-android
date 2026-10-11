# NORA — Architecture du prototype Android

> Itération 0 · octobre 2026 · proposition à valider avant l'itération 1

## 1. Principes directeurs

| Exigence du cahier des charges | Réponse architecturale |
|---|---|
| 100 % hors connexion | Aucune dépendance réseau dans les couches capture, IA et modules. Les modèles sont embarqués (APK + packs de modèles copiés localement). Seuls l'appel et le SMS sortent du téléphone, via le réseau GSM, pas internet. |
| Modules développables, testables et démontrables séparément | Chaque module est un package Dart autonome avec sa propre mini-app de démo (`example/`). Il ne dépend que de contrats (`nora_core`), jamais d'un autre module ni d'un moteur d'IA concret. |
| 4 langues, dont 2 peu dotées | Les messages sont des **identifiants paramétrés**, pas des phrases. Chaque moteur déclare les langues qu'il couvre. Une chaîne de repli choisit : enregistrement natif → synthèse vocale → langue de repli de l'utilisateur. |
| 5 profils, un seul outil | Les sorties (voix, texte, vibration, flash) sont choisies selon le profil, priorisées et dédoublonnées par une politique commune à tous les modules. |
| Smartphone grand public | Un seul module « lourd » actif à la fois ; inférence hors du fil d'interface ; mesures systématiques sur un téléphone de référence. |

## 2. Les quatre couches

```
 CAPTURE                IA LOCALE                  MODULES MÉTIER                  SORTIE
 ───────                ─────────                  ──────────────                  ──────
 Caméra ─ CameraFrame ─▶ ObjectDetector    ─┐      Vision
                         TextRecognizer    ─┤        └ malvoyant              ┌▶ FeedbackPolicy
 Micro ── AudioChunk ──▶ SoundClassifier   ─┼────▶ Communication       ──────┤   priorité, anti-répétition,
                         SpeechRecognizer  ─┘        ├ malentendant           │   canaux selon le profil
 GPS ──── GeoPosition ─────────────────────────▶     └ trouble de la parole   │
                                                   Sécurité / cognitif         └▶ VoiceRenderer → haut-parleur
                         SpeechSynthesizer ◀──────   ├ moteur (commandes)         clips natifs ou synthèse
                                                     └ cognitif (rappels)      + texte · vibration · flash
```

| Couche | Contrats (`nora_core`, pur Dart) | Implémentations (packages séparés) |
|---|---|---|
| Capture | `MicrophoneSource`, `CameraSource`, `LocationSource` | `nora_capture` |
| IA locale | `ObjectDetector`, `TextRecognizer`, `SpeechRecognizer`, `SoundClassifier`, `SpeechSynthesizer` | `nora_engine_vision`, `nora_engine_audio` (choix des bibliothèques : point 2) |
| Modules | `NoraModule`, `ModuleHost` | `nora_vision`, `nora_hearing`, `nora_speech_assist`, `nora_voice_control`, `nora_reminders` |
| Sortie | `NoraFeedback`, `FeedbackPolicy`, `VoiceRenderer`, `MessageCatalog`, `ClipPlayer` | `nora_output` |

## 3. Arborescence

```
nora/
├── pubspec.yaml                  workspace Dart (pub workspaces : Dart ≥ 3.6, Flutter ≥ 3.27)
├── docs/ARCHITECTURE.md          ce document
├── apps/
│   └── nora_app/                 application finale : assemble les modules, onboarding, profil, réglages
├── packages/
│   ├── nora_core/                ✅ contrats + logique de sortie (pur Dart, testé avec `dart test`)
│   ├── nora_ui/                  composants accessibles : TalkBack, contrastes, gros boutons, arabe en RTL
│   ├── nora_capture/             caméra, micro, GPS → CameraFrame / AudioChunk / GeoPosition
│   ├── nora_output/              synthèse + clips, vibration, flash, bandeau texte
│   ├── engines/                  moteurs d'IA embarqués (dépendances natives lourdes, isolées ici)
│   │   ├── nora_engine_vision/   détection d'objets (TFLite), OCR
│   │   └── nora_engine_audio/    reconnaissance vocale, détection de voix, synthèse, sons
│   └── modules/
│       ├── nora_vision/          [Vision]               malvoyant : obstacles, lecture de texte
│       ├── nora_hearing/         [Communication]        malentendant : sons + parole → texte
│       ├── nora_speech_assist/   [Communication]        trouble de la parole : clarification
│       ├── nora_voice_control/   [Sécurité/cognitif]    moteur : appeler, envoyer sa position, taxi
│       └── nora_reminders/       [Sécurité/cognitif]    cognitif : rappels
├── models/                       hors git : fichiers de modèles + manifest.yaml (version, langue, taille, sha256)
└── ml/                           Python : collecte, annotation, entraînement, conversion, évaluation
    ├── data_collection/          protocoles de collecte, formulaires de consentement
    ├── vision/                   fine-tuning du détecteur sur les obstacles locaux → .tflite
    ├── audio/                    évaluation reconnaissance/synthèse par langue
    └── speech_assist/            banque de phrases, adaptation au locuteur
```

Les trois modules du dossier (Vision, Communication, Sécurité/cognitif) sont conservés comme regroupement ; chacun est découpé en packages par profil pour qu'un profil puisse être démontré seul.

### Structure interne d'un module (exemple : `nora_vision`)

```
nora_vision/
├── pubspec.yaml                  dépend de nora_core et nora_ui, jamais d'un moteur
├── lib/
│   ├── nora_vision.dart          API publique : VisionModule, VisionScreen
│   └── src/
│       ├── domain/               pur Dart, testé sans téléphone
│       │   └── obstacle_analyzer.dart   détections → obstacles (zone, proximité, persistance)
│       ├── vision_module.dart    orchestration : caméra → détecteur → analyse → NoraFeedback
│       └── ui/                   écran du module, réglages
├── assets/
│   ├── messages/                 fr.json · ar.json · so.json · aa.json (textes du module)
│   └── voice/                    so/ · aa/ (clips enregistrés par des locuteurs natifs)
├── test/                         tests unitaires avec moteurs factices
└── example/                      mini-app : le module seul, câblé sur les vrais moteurs (démo jury, tests terrain)
```

Chaque module embarque ses propres messages et clips : sa mini-app de démo fonctionne sans le reste de NORA.

## 4. Règles de dépendance

```
apps/nora_app, */example ──▶ modules/* ──▶ nora_core ◀── engines/*, nora_capture, nora_output
          │                                                  ▲
          └──────────────── câblage (injection) ─────────────┘
```

1. **Un module n'importe jamais un autre module ni un moteur.** On peut retirer, remplacer ou livrer seul n'importe quel module.
2. **Les moteurs sont isolés dans `engines/`.** TensorFlow Lite, ONNX Runtime et les modèles ne sont tirés que par l'app et les `example/`. Un module se teste sur PC avec des moteurs factices.
3. **Le câblage** (quelle implémentation pour quel contrat) se fait uniquement dans `apps/nora_app` et dans les `example/`. Riverpod par défaut : ses *overrides* remplacent un moteur par un faux en test, ou un moteur de langue par un autre.
4. **`nora_core` reste en pur Dart** : aucune dépendance à Flutter, tests en quelques secondes.

## 5. Budget de calcul

| Module | Coût | Raison |
|---|---|---|
| Vision (détection continue) | lourd | 5–10 inférences par seconde |
| Audition (transcription continue) | lourd | reconnaissance vocale en flux |
| Parole (clarification) | lourd, à la demande | inférence sur un énoncé, déclenchée par un bouton |
| Commandes vocales (mot d'éveil) | léger | très petit modèle de mots-clés |
| Rappels | léger | notifications planifiées |

- `ModuleHost` garantit **un seul module lourd actif** ; les modules légers restent actifs en parallèle.
- L'inférence tourne dans un isolat (ou un thread natif) ; le détecteur ne traite que **la dernière image** disponible (on jette au lieu de mettre en file) : la latence reste constante même si le téléphone est lent.
- **Téléphone de référence** : 1 ou 2 modèles représentatifs du marché djiboutien (entrée/milieu de gamme, 3–4 Go de RAM, Android 11+), achetés dès le début. Images/seconde, latence, température et batterie y sont mesurées à chaque itération. Objectif : alerte obstacle en moins de 500 ms entre l'image et la vibration.

## 6. Langues

- Chaque moteur expose `supports(langue)` : la matrice des capacités est calculée à l'exécution et l'app affiche honnêtement ce qui fonctionne dans chaque langue.
- `VoiceRenderer` applique la chaîne de repli, langue par langue dans l'ordre de l'utilisateur :
  1. **clips enregistrés** par des locuteurs natifs (meilleure intelligibilité pour les messages fixes ; seule option fiable en somali et en afar à court terme) ;
  2. **synthèse vocale**, si un moteur couvre la langue ;
  3. **langue suivante** (ex. afar → français), le texte restant affiché.
- Le texte libre (texte lu par l'OCR, phrase transcrite) n'a pas d'enregistrement possible : synthèse uniquement.
- **Conséquence pour la collecte (mois 1–2)** : les messages des modules Vision, Audition et Sécurité forment un ensemble fini (quelques centaines de clips au plus). Ils peuvent être enregistrés en somali et en afar par des locuteurs natifs en quelques jours. Attention : enchaîner des fragments (« obstacle » + « personne » + « proche ») peut être agrammatical en somali ou en afar (ordre des mots, accords). Il faut enregistrer des phrases entières pour les combinaisons fréquentes et faire valider par un linguiste.

## 7. Données personnelles

- Rien ne quitte le téléphone : pas de compte, pas de serveur, pas de télémétrie.
- Les enregistrements vocaux du module Parole (données sensibles) sont chiffrés sur l'appareil, avec consentement explicite et suppression possible à tout moment.

## 8. Les trois scénarios du MVP dans l'architecture

**Malvoyant : détection d'obstacle**
`CameraSource` (dernière image, 5–10/s) → `ObjectDetector` (isolat) → `ObstacleAnalyzer` : garde les objets du couloir central, classe la proximité en proche / moyen / loin d'après la taille et la position de la boîte, exige 2–3 images consécutives pour éviter les fausses alertes → `NoraFeedback(CatalogMessage('vision.obstacle', {object: person, distance: near}), danger)` → `FeedbackPolicy` (voix + vibration, coupe la parole en cours) → `VoiceRenderer` : « Attention, personne devant, proche ».

**Malentendant : sons et parole en texte**
`MicrophoneSource` (flux partagé) alimente deux branches :
- `SoundClassifier` → sons importants (klaxon, sirène, sonnette, pleurs de bébé, alarme) → `NoraFeedback` (alerte) → bandeau + vibration + flash ;
- détection de voix → `SpeechRecognizer` en flux → sous-titres en direct (résultats partiels puis définitifs) affichés par l'écran du module.

**Trouble de la parole : clarification**
- *Enrôlement* : l'utilisateur, avec un aidant, enregistre plusieurs fois chacune de ses phrases utiles (20 à 50). L'aidant saisit le texte et peut enregistrer une version claire.
- *Usage* : appui sur un grand bouton → micro → découpage de l'énoncé → comparaison avec la banque personnelle → meilleure correspondance + score. Si la confiance est suffisante, la phrase est affichée en grand et prononcée (clip de l'aidant ou synthèse) ; sinon, les 3 meilleures propositions s'affichent et l'utilisateur choisit.
- Chaque phrase personnelle est un `CatalogMessage('speech.phrase', {id: …})` résolu par un catalogue personnel. Elle profite donc de la même chaîne de repli, y compris en afar.

## 9. Points d'alerte : ambitions à recadrer

1. **« Description vocale de l'environnement »** : en temps réel, hors connexion, sur un téléphone d'entrée de gamme, c'est réaliste sous la forme *détection + règles + phrases modèles*, pas d'une description libre. Les petits modèles vision-langage embarqués (famille Gemma 3n, SmolVLM…) demandent plusieurs secondes par image et 2–4 Go de RAM, et ne parlent ni somali ni afar de façon fiable. → Formulation proposée pour le dossier : « signalement des obstacles et lecture de texte ». Une option « décris-moi la scène » à la demande pourra être ajoutée plus tard, sur les téléphones compatibles.
2. **Distance** : une caméra seule ne mesure pas une distance fiable. → Catégories proche / moyen / loin ; pas de mètres dans la démo.
3. **Obstacles locaux** : les modèles entraînés sur COCO (80 classes) reconnaissent personnes, véhicules, vélos, chaises, certains animaux, mais **pas** les trous, caniveaux ouverts, marches, bordures de trottoir ou poteaux. → La collecte d'images à Djibouti (mois 1–2) et le fine-tuning du détecteur sont le cœur de la valeur locale du projet.
4. **Clarification d'une parole atypique** : reconnaître une parole dysarthrique en vocabulaire libre, hors connexion, en 4 langues, reste un problème de recherche ouvert. → MVP réaliste : la banque de phrases personnelle décrite ci-dessus. Elle dépend du locuteur, mais fonctionne dans toutes les langues, y compris l'afar. Détails au point 2.
5. **Appel, position, taxi** : sans internet, un appel ou un SMS reste possible mais exige le réseau GSM. Un taxi accessible exige un partenaire. → « Appeler ou envoyer par SMS sa position GPS à un numéro prédéfini (proche, taxi partenaire) ».
6. **Licence du détecteur** : YOLOv8 / YOLO11 d'Ultralytics sont sous **AGPL-3.0**. Si l'app est distribuée, son code source doit être publié sous AGPL, sauf achat de la licence commerciale Ultralytics. → Deux options : assumer NORA en open source (argument « bien public » pour le jury), ou prendre un détecteur sous Apache-2.0 (EfficientDet-Lite via MediaPipe, YOLOX). **À décider avant l'itération 1.** Les modèles vocaux demandent la même vérification (certains sont non commerciaux : point 2).
7. **OCR arabe** : ML Kit (Google, hors connexion) lit l'écriture latine, donc le français, le somali et l'afar, mais **pas l'arabe**. → La lecture de texte arabe demande un autre moteur (Tesseract, PaddleOCR). Hors MVP.
8. **Taille et distribution** : ordre de grandeur de quelques Mo pour la vision, 30 à 250 Mo par langue pour la reconnaissance et la synthèse vocales. → Packs de modèles par langue ; installation hors ligne (APK + pack copié depuis un PC ou une carte SD) pour les tests pilotes ANPH.

## 10. Plan d'itérations

| It. | Contenu | Démontrable |
|---|---|---|
| 0 ✅ | Workspace + `nora_core` : contrats, politique de sortie, repli linguistique, `ModuleHost`, tests | `dart test` |
| 1 | `nora_capture` (caméra) + `nora_engine_vision` + `nora_vision` (analyse d'obstacles) + `example/` | Malvoyant : « Attention, personne devant, proche » + vibration, en français |
| 2 | Micro + classification de sons + transcription en français → `nora_hearing` | Malentendant : klaxon → bandeau + vibration ; parole → sous-titres |
| 3 | `nora_speech_assist` : enrôlement + banque de phrases | Trouble de la parole : phrase reconnue, affichée et prononcée |
| 4 | Arabe, somali, afar (clips natifs + moteurs du point 2) | Les trois démos dans les 4 langues |
| 5+ | Commandes vocales, rappels, app assemblée, onboarding accessible | Les cinq profils |

Le MVP (itérations 1 à 3) tient dans les mois 2 à 4 du calendrier. Les mois 5 et 6 restent pour les modules moteur et cognitif et pour l'intégration du somali et de l'afar, avant les tests pilotes (mois 7 à 9).
