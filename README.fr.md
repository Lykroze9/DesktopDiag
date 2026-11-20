# DesktopDiag

### Ton PC est lent, a des petits bugs, plante... ou tu veux juste faire un petit checking ?

DesktopDiag passe ton Windows au crible et t'explique simplement ce qui ne va pas, et quoi faire.

> **👋 Un projet perso.** DesktopDiag est né comme un outil fait sur mesure pour mon propre PC,
> après des semaines à traquer des freezes GPU et des écrans bleus, puis il est devenu un skill que
> j'ai eu envie de partager. Ce n'est pas un produit commercial, et il est loin d'être terminé.
>
> **N'hésite pas à laisser ton avis !** Tu l'as essayé ? Un bug, un diagnostic à côté de la plaque,
> un contrôle qui manque, ou juste une idée ? [Ouvre une issue](https://github.com/Lykroze9/DesktopDiag/issues)
> ou lance une [discussion](https://github.com/Lykroze9/DesktopDiag/discussions), en français ou en anglais. Chaque retour aide à améliorer le skill.

**Diagnostic de santé Windows en lecture seule pour Claude Code.** Demande « fais un check du PC »
ou décris ton problème (« écran noir en jeu », « le PC redémarre tout seul ») : Claude collecte les
infos, les explique simplement, donne une note à ton PC et te dit quoi faire. Rapports en
**français ou en anglais**.

[🇬🇧 English version](README.md)

## Sans Claude : l'appli Windows

Tu n'utilises pas Claude ? Télécharge **DesktopDiag.exe** : un seul fichier portable (environ 1 Mo),
rien à installer.

**[⬇️ Télécharger DesktopDiag.exe](https://github.com/Lykroze9/DesktopDiag/releases/latest/download/DesktopDiag.exe)** · [Notes de version et SHA-256](https://github.com/Lykroze9/DesktopDiag/releases/latest)

<p>
  <img src="docs/images/app-home-fr.png" width="49%" alt="Accueil de DesktopDiag : gros bouton Lancer le check, choix du symptôme, dernier check et courbe de la note">
  <img src="docs/images/app-results-fr.png" width="49%" alt="Résultats de DesktopDiag : note 74/100, évolution depuis le dernier check, conseils étape par étape">
</p>

- **Un clic**, moins d'une minute : une note sur 100 et chaque domaine expliqué simplement
  (OK / À voir / Urgent).
- **Conseils en 3 parties** (ce que c'est, pourquoi c'est important, comment faire), un bouton
  **Ouvrir pour moi** vers le bon écran de Windows, et **C'est fait**, vérifié au check suivant.
- **Analyse approfondie** en option avec les droits admin : santé des SSD (SMART), analyse des
  écrans bleus avec le pilote en cause probable, durée réelle du démarrage, vérification du disque.
- Mode symptôme (« écran bleu », « PC lent »…), courbe de la note, comparaison de deux checks,
  **PDF**, copie pour un forum, vue technicien, 4 thèmes, taille du texte, **français ou anglais**.
- Mêmes contrôles et mêmes règles que le skill Claude. **Lecture seule**, pas de compte, pas de
  télémétrie. Elle vérifie seulement une fois par jour s'il existe une nouvelle version sur GitHub
  (désactivable) ; les mises à jour sont vérifiées par SHA-256.

**Premier lancement :** l'appli n'est pas encore signée, donc Windows SmartScreen peut afficher
*« Windows a protégé votre ordinateur »*. Clique sur **Informations complémentaires**, puis sur
**Exécuter quand même**. Tu peux comparer le fichier avec le SHA-256 de la release, et tout le code
est dans [`app/`](app/). Il faut Windows 10 22H2 ou 11 (x64) et le composant Microsoft Edge WebView2,
déjà présent sur Windows 11 et sur les Windows 10 à jour.

## Ce qui est vérifié

| Domaine | Détails |
|---|---|
| Stabilité | Écrans bleus (code d'arrêt + paramètres), arrêts inattendus, fichiers de vidage, indice de fiabilité Windows |
| Carte graphique | Réinitialisations du pilote (TDR), erreurs NVIDIA/AMD/Intel, version et âge du pilote, outils d'overclocking au démarrage |
| Stockage | Espace libre, santé des disques, usure/température/erreurs SSD (SMART via smartctl), erreurs disque rattachées au bon disque (USB ou SSD système) |
| Matériel | Erreurs matérielles WHEA (CPU, RAM, PCIe), résultat du test mémoire Windows, erreurs TPM, périphériques en erreur (code 10/43...) |
| Sécurité | Antivirus, pare-feu, dernière mise à jour Windows réussie et échecs récents, redémarrage en attente, UAC, Secure Boot |
| Performances | Vrai % CPU (mesuré, pas cumulé), RAM et mémoire engagée, processus les plus gourmands |
| Démarrage | Durée du BIOS à chaque démarrage, démarrage rapide ; avec l'étape admin : durée totale du démarrage et ce qui l'a ralenti (appli, pilote, service) |
| Chauffe | Bridage du processeur par le BIOS (chaleur ou limite de puissance), limitation en direct, zones thermiques si le PC les expose |
| Réseau | Signal Wi-Fi, ping de la box, temps de réponse DNS, coupures Wi-Fi et Ethernet |
| Batterie | Portables : santé (capacité actuelle par rapport à neuve) et cycles de charge |
| Entretien | Programmes au démarrage, dossiers temporaires, durée depuis le dernier redémarrage, taille de la mémoire virtuelle et du fichier d'hibernation |
| Historique | Chaque check est sauvegardé en local et comparé au précédent : nouveaux plantages, espace perdu, mises à jour de pilote/BIOS, nouveaux programmes au démarrage |
| Suivi | Après chaque rapport, Claude propose le prochain check adapté à ce qu'il a trouvé (dans 2 à 4 jours après une correction, chaque semaine tant qu'un problème se stabilise, sinon chaque mois) et le programme avec ton accord via les tâches planifiées locales de l'appli Claude |

## Pourquoi un de plus ?

Les skills et serveurs MCP de diagnostic Windows existants passent à côté des vrais problèmes :
plantages du pilote graphique, usure des SSD NVMe, pilote responsable d'un écran bleu, et « est-ce
que ça va mieux depuis la semaine dernière ? ». DesktopDiag en plus :

- tourne avec **Windows PowerShell 5.1 déjà installé** (ni PowerShell 7, ni Node, ni Python), sous Windows 10 et 11 ;
- n'a **pas besoin des droits admin** pour le check principal ; une étape admin optionnelle ajoute SMART, l'analyse des écrans bleus et un scan du système de fichiers en lecture seule ;
- est **en lecture seule** : les corrections sont proposées avec un niveau de risque et lancées seulement après ton accord explicite ;
- documente les pièges rencontrés en vrai (plantages comptés en double dans le journal Application, `chkdsk` « Accès refusé », utilitaires constructeur qui réinstallent des pilotes, écritures registre virtualisées...) ;
- a un **mode partage** qui retire ton nom d'utilisateur, le nom du PC et les chemins pour poster sur un forum.

## Installation

### Comme plugin Claude Code

```
/plugin marketplace add Lykroze9/DesktopDiag
/plugin install desktopdiag@desktopdiag
```

### Comme skill seul

Copie `skills/desktopdiag` dans `%USERPROFILE%\.claude\skills\desktopdiag` (tous les projets) ou
dans `.claude\skills\desktopdiag` d'un projet.

## Utilisation

Parle simplement à Claude Code :

- « Fais un check du PC » / « Mon PC va bien ? »
- « J'ai des écrans noirs de quelques secondes en jeu »
- « Mon PC a redémarré tout seul deux fois cette semaine »
- « Mon SSD est en bon état ? »
- « Fais un check complet » (propose l'analyse admin)
- « Fais-moi un rapport partageable pour un forum »
- « Programme un check tous les mois » / « Refais un check dans 4 jours »

Tu peux aussi lancer la collecte toi-même :

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File skills\desktopdiag\scripts\collect.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File skills\desktopdiag\scripts\compare.ps1
```

Ajoute `-Summary` à `collect.ps1` pour un résumé compact (environ 10 fois plus petit que le relevé
complet). Claude l'utilise par défaut : chaque check consomme beaucoup moins de tokens.

Les relevés sont stockés dans `%LOCALAPPDATA%\DesktopDiag\history`.

## Note

La note et le niveau de chaque domaine viennent de `skills/desktopdiag/rules/rules.json`, appliqué
par `scripts/score.ps1` : le même PC a toujours la même note, et Claude ajoute les explications.
Les seuils sont décrits dans [rules/README.md](skills/desktopdiag/rules/README.md).

## Développement

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\run-tests.ps1 -Live
```

Les tests utilisent des relevés fictifs (`tests/fixtures.ps1`, aucune donnée d'un vrai PC) et tournent
à chaque push avec GitHub Actions, avec PSScriptAnalyzer. Les nouveautés sont dans [CHANGELOG.md](CHANGELOG.md).

L'appli Windows (`app/`) est en C# 5, compilée avec le compilateur du .NET Framework 4.8 déjà présent
sur Windows, avec une interface HTML/CSS dans WebView2. Mets les trois fichiers du SDK WebView2
(`Microsoft.Web.WebView2.Core.dll`, `Microsoft.Web.WebView2.WinForms.dll`, `WebView2Loader.dll` en x64,
tirés du paquet NuGet `Microsoft.Web.WebView2` 1.0.4258.31) dans `app\lib`, puis lance `app\build.ps1`.
Elle embarque les scripts et les règles du skill : l'appli et le skill partagent toujours les mêmes
contrôles.

## Outils optionnels

- [smartmontools](https://www.smartmontools.org/) (`winget install smartmontools.smartmontools`) pour les données SMART détaillées des SSD/disques durs.
- WinDbg (`winget install Microsoft.WinDbg`) pour identifier le pilote responsable d'un écran bleu. La première analyse télécharge les symboles publics de Microsoft.

## Confidentialité

Tout tourne en local. Rien n'est envoyé (sauf le téléchargement des symboles Microsoft si tu acceptes
l'analyse des écrans bleus). Les numéros de série des disques sont hachés. Utilise le mode partage
avant de publier un rapport.

## Avertissement

DesktopDiag lit des informations système et donne des conseils. Il ne remplace pas un technicien.
Les interventions matérielles (mise à jour du BIOS, changement de pâte thermique, remplacement de
pièces) restent ta décision et ta responsabilité.

## Licence

MIT
