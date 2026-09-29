# NeuroSigne

Application mobile (Android, iOS, Web) de traduction de la
**Langue des Signes Française (LSF)**.

## Fonctionnalités

### Utilisateur (profil unique)

| Besoin | Où le trouver |
| --- | --- |
| Création de compte (nom, e-mail, mot de passe) et connexion sécurisée (Firebase Auth) | Écrans *Créer un compte* / *Connexion*, avec « Mot de passe oublié » |
| Signer devant la caméra ➜ texte et voix | Onglet **Traduire › Je signe** |
| Parler ou écrire ➜ LSF | Onglet **Traduire › Je parle** (reconnaissance vocale réelle) |
| Converser avec un ou plusieurs interlocuteurs | Onglet **Traduire › Groupe** |
| Dictionnaire LSF (recherche par mot, catégorie ou paramètres du geste) | Onglet **Dictionnaire**, disponible hors ligne |
| Historique des traductions et conversations | Accueil et **Profil › Historique** |
| Notifications en temps réel | Cloche de l'accueil (Firestore `announcements` en ligne) |
| Explication en LSF de tout texte | Bouton « Voir en LSF » (icône mains) présent sur les écrans |

### Préférences (**Profil › Préférences**)

- Mode de réception des réponses : texte affiché, vidéo ou avatar signant
- Style de l'avatar (bibliothèque gérée par l'administration)
- Langue de l'interface (français / anglais)
- Thème clair ou sombre

### Administrateur

| Section | Contenu |
| --- | --- |
| Aperçu | Statistiques globales : traductions, recherches, comptes, signes les plus recherchés |
| Signes | Validation ou rejet des signes proposés par la communauté |
| Comptes | Utilisateurs et administrateurs : création, promotion, suspension, suppression |
| Avatars | Bibliothèque des styles d'avatars (ajout, modification, suppression) |
| Système | Modèle d'IA (adresse, version, test de connexion, historique), notifications, règles de sécurité |

## Conversations de groupe

Onglet **Traduire › Groupe** :

- **À distance** (compte Firebase connecté) : chacun sur son téléphone, en
  temps réel. Un salon se rejoint avec son **code à 6 caractères** ou depuis une
  **invitation par e-mail**. Chaque message reçu s'affiche en LSF (avatar,
  vidéo ou texte) et peut être lu à voix haute ; on écrit, dicte ou **signe**
  ses messages. Présence en ligne, messages non lus, notifications en temps
  réel. L'organisateur clôture le salon ; la conversation reste dans
  l'historique.
- **Face à face** : un seul téléphone partagé, sans connexion.

## Firebase

Projet : `zhenu-f0838`. Données Firestore :

| Collection | Contenu | Écriture |
| --- | --- | --- |
| `users/{uid}` | profil, rôle (`user` / `admin`), suspension | l'utilisateur (sauf rôle/suspension), l'admin |
| `conversations/{id}` + `messages` | salons et messages | participants |
| `roomCodes/{code}` | code ➜ salon | organisateur |
| `signs`, `signProposals` | dictionnaire publié, propositions | admin ; propositions par tous |
| `config/app` | réglages, avatars, modèle d'IA | admin |
| `announcements` | notifications | admin |
| `stats/global` | statistiques d'usage | incrément par tous, lecture admin |

Hors ligne ou sans compte Firebase, l'application utilise les copies locales
(cache Firestore et stockage de l'appareil).

### Mise en service

1. Console Firebase › **Authentication** : activer « E-mail/Mot de passe ».
2. Console Firebase › **Firestore** : créer la base.
3. Déployer les règles de sécurité :
   ```bash
   firebase deploy --only firestore
   ```
4. Premier administrateur : créer le compte dans l'application, puis dans la
   console Firestore passer `users/{uid}.role` à `admin`. Les administrateurs
   suivants se créent depuis **Administration › Comptes**.

### Tester les règles (émulateur local)

```bash
cd firestore-tests
npm install
npm test
```

## Sécurité

- L'inscription publique crée **toujours** un compte utilisateur. Seul un
  administrateur peut créer ou promouvoir un administrateur.
- Les comptes de démonstration (`user@test.com`, `admin@test.com`, mot de passe
  `password`) ne sont acceptés **qu'en mode développement** ou sans Firebase.
- En mode local, les mots de passe sont hachés (SHA-256), jamais stockés en clair.
- Déconnexion automatique après inactivité (réglable par l'administration).
- Règles Firestore (`firestore.rules`, testées dans `firestore-tests/`) :
  personne ne s'attribue le rôle admin, les messages ne sont lisibles que par
  les participants, aucun message ne peut être envoyé au nom d'un autre, et
  un compte suspendu ne peut plus écrire.

## Lancement

```bash
flutter pub get
flutter run
```

### Modèle de reconnaissance des signes

Serveur EchoSign Vision (FastAPI) : `/health`, `/signs`, `/ws/recognize`,
`/predict/sequence`.

1. Lancer le serveur sur le PC, puis trouver son adresse IP avec `ipconfig`
   (ex. `192.168.100.132`). Sur le téléphone, **ne pas utiliser `localhost`**.
2. Téléphone et PC sur le **même Wi-Fi** ; autoriser le port 8000 dans le
   pare-feu Windows.
3. Dans **Administration › Système › Mettre à jour**, saisir
   `http://<IP-du-PC>:8000`, puis **Tester la connexion** : le nombre de signes
   reconnus s'affiche.

L'application en déduit `ws://<IP>:8000/ws/recognize`. L'adresse peut aussi
être fixée à la compilation :

```bash
flutter run --dart-define=ECHOSIGN_URL=http://192.168.100.132:8000
```

- Les gloses du modèle sont rendues lisibles (`A_BIENTOT` ➜ « A BIENTOT »,
  `ADAPTER-NEG` ➜ « ADAPTER (NÉGATION) »).
- Sous le seuil de confiance, la meilleure hypothèse est proposée
  (« Signe incertain : MERCI (31 %) ») et peut être validée.
- Une image n'est envoyée qu'après la réponse à la précédente : le délai
  reste borné même si le serveur est lent.
- L'extraction des points clés (MediaPipe) est disponible sur **Android**. Sur
  iOS, Web ou sans serveur joignable, la caméra passe en **mode démonstration**
  (badge « Démo »).
- `http://` / `ws://` sont autorisés pour le réseau local ; en production,
  utiliser `https://` / `wss://`.

Test en direct du serveur :

```bash
flutter test test/echosign_api_client_test.dart --dart-define=ECHOSIGN_LIVE=http://localhost:8000
```

### Médias des signes (vidéos / avatars animés)

Les animations sont fournies via `--dart-define-from-file=sign_media.json` :

```json
{
  "SIGN_MEDIA_JSON": "{\"bonjour\":{\"guide\":\"https://…/bonjour-guide.gif\",\"video\":\"https://…/bonjour.gif\"}}"
}
```

Les clés sont les mots en minuscules ; les sous-clés sont les styles d'avatar
(`guide`, `female`, `male`, `neutral`, `illustrated`) et `video`. En l'absence
de média, l'application affiche l'avatar avec la description du geste.

## Architecture

```
lib/
  core/          thème, couleurs, préférences, traductions (tr)
  data/
    constants/   signes LSF de référence, comptes de démonstration
    services/    authentification, signes, reconnaissance, médias,
                 voix, notifications, historique, administration
  presentation/
    screens/     écrans utilisateur ; admin/ pour l'administration
    widgets/     composants partagés (ui_kit, rendu LSF, avatar…)
```

## Tests

```bash
flutter test
# Captures d'écran de revue visuelle (build/screenshots) :
flutter test test/screenshots_test.dart --dart-define=SCREENSHOTS=true
```
