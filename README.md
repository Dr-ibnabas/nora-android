# NORA

Assistant IA hors connexion pour l'autonomie des personnes en situation de handicap à Djibouti (français, arabe, somali, afar).

- Architecture, choix techniques et points d'alerte : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- État : itération 0, workspace et contrats partagés (`packages/nora_core`)

## Prérequis

Flutter ≥ 3.27 (Dart ≥ 3.6, requis pour les *pub workspaces*).

## Lancer les tests

À la racine du dépôt :

```bash
dart pub get
```

Puis depuis `packages/nora_core` :

```bash
dart test
```
