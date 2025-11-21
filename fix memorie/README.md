# Fix Extensions

Petit outil PowerShell qui :
- extrait tous les fichiers `.zip` dans un dossier, puis supprime les archives ;
- lit la signature binaire des fichiers pour corriger les extensions (jpg/png/gif/mp4) ;
- aplatit le contenu extrait dans le dossier cible.

## Utilisation rapide (graphique)
1) Double-clique `fix_extensions.cmd`.
2) Choisis/colle le chemin de ton dossier.
3) Laisse le script tourner jusqu’au message `Done.`.

## Utilisation en ligne de commande
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\fix_extensions.ps1" -Path "C:\chemin\vers\dossier"
```

## Notes
- Les `.zip` sont supprimés après extraction.
- Les fichiers inconnus sont laissés tels quels.
- En cas de doublon lors d’un renommage, un suffixe aléatoire est ajouté pour éviter d’écraser un fichier existant.
