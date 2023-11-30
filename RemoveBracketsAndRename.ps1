# Définir le chemin du dossier contenant les fichiers à renommer
$folderPath = "D:\Users\Romain\Videos\Papa"

# Obtenir tous les fichiers dans le dossier
$files = Get-ChildItem -Path $folderPath -File

foreach ($file in $files) {
    # Capturer le nom de fichier actuel
    $currentName = $file.Name

    # Utiliser une expression régulière pour enlever tout ce qui se trouve entre les crochets inclus
    $newName = $currentName -replace '\s*\[.*?\]\s*', ''

    # Construire le chemin complet des nouveaux et anciens fichiers
    $oldFullPath = [System.IO.Path]::Combine($folderPath, $currentName)
    $newFullPath = [System.IO.Path]::Combine($folderPath, $newName)

    # Renommer le fichier
    Rename-Item -LiteralPath $oldFullPath -NewName $newName
}

# Afficher un message une fois que les opérations de renommage sont terminées
Write-Host "Renommage des fichiers terminé."
