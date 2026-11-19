# DesktopDiag

> **👋 Un projet perso.** DesktopDiag est né comme un outil fait sur mesure pour mon propre PC,
> après des semaines à traquer des freezes GPU et des écrans bleus, puis il est devenu un skill que
> j'ai eu envie de partager. Ce n'est pas un produit commercial, et il est loin d'être terminé.
>
> **N'hésite pas à laisser ton avis !** Tu l'as essayé ? Un bug, un diagnostic à côté de la plaque,
> un contrôle qui manque, ou juste une idée ? [Ouvre une issue](https://github.com/Lykroze9/DesktopDiag/issues),
> en français ou en anglais. Chaque retour aide à améliorer le skill.

**Diagnostic de santé Windows en lecture seule pour Claude Code.** Demande « fais un check du PC »
ou décris ton problème (« écran noir en jeu », « le PC redémarre tout seul ») : Claude collecte les
infos, les explique simplement, donne une note à ton PC et te dit quoi faire. Rapports en
**français ou en anglais**.

[🇬🇧 English version](README.md)

## Ce qui est vérifié

| Domaine | Détails |
|---|---|
| Stabilité | Écrans bleus (code d'arrêt + paramètres), arrêts inattendus, fichiers de vidage, indice de fiabilité Windows |
| Carte graphique | Réinitialisations du pilote (TDR), erreurs NVIDIA/AMD/Intel, version et âge du pilote, outils d'overclocking au démarrage |
| Stockage | Espace libre, santé des disques, usure/température/erreurs SSD (SMART via smartctl), erreurs disque rattachées au bon disque (USB ou SSD système) |
| Matériel | Erreurs matérielles WHEA (CPU, RAM, PCIe), erreurs TPM, périphériques en erreur (code 10/43...) |
| Sécurité | Antivirus, pare-feu, dernière mise à jour Windows réussie et échecs récents, redémarrage en attente, UAC, Secure Boot |
| Performances | Vrai % CPU (mesuré, pas cumulé), RAM et mémoire engagée, processus les plus gourmands |
| Entretien | Programmes au démarrage, dossiers temporaires, durée depuis le dernier redémarrage |
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

Les relevés sont stockés dans `%LOCALAPPDATA%\DesktopDiag\history`.

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
