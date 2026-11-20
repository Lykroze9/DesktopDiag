// "Quoi de neuf": shown once after an update, and when clicking the version in the footer.
// Add an entry for each app release (newest first), with its publication date.
window.WHATSNEW = {
  "1.0.1": {
    date: "2026-11-20",
    fr: ["Plus aucun passage par PowerShell en mode « Bypass » : les contrôles tournent dans l'appli elle-même. Les antivirus devraient beaucoup moins la confondre avec un logiciel malveillant.",
      "L'analyse approfondie demande l'autorisation administrateur au nom de DesktopDiag.",
      "Informations sur l'éditeur ajoutées au fichier (Lykroze, version, licence).",
      "Les mises à jour sont vérifiées à chaque lancement (désactivable dans les réglages)."],
    en: ["No more PowerShell in \"Bypass\" mode: the checks run inside the app itself. Antivirus software should be far less likely to mistake it for malware.",
      "The deep scan asks for administrator permission in DesktopDiag's name.",
      "Publisher details added to the file (Lykroze, version, license).",
      "Updates are checked at every launch (can be turned off in settings)."]
  },  "1.0.0": {
    date: "2026-11-20",
    fr: ["Première version de DesktopDiag : check en un clic, note sur 100, conseils détaillés.",
      "« Ouvrir pour moi », « C'est fait », courbe de la note, mode symptôme, PDF, copie pour un forum.",
      "Analyse approfondie avec les droits administrateur (SSD, écrans bleus, démarrage).",
      "Mise à jour automatique depuis GitHub, vérifiée par SHA-256."],
    en: ["First version of DesktopDiag: one-click check, score out of 100, detailed advice.",
      "\"Open it for me\", \"Done\", score curve, symptom mode, PDF, copy for a forum.",
      "Deep scan with administrator rights (SSD, blue screens, startup).",
      "Automatic updates from GitHub, checked with SHA-256."]
  }
};
