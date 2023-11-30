Add-Type -AssemblyName System.Windows.Forms

# Fonction pour simuler une frappe au clavier
Function Send-KeyPress {
    param([string]$Key)
    [System.Windows.Forms.SendKeys]::SendWait($Key)
}

# Fonction pour vérifier si l'heure actuelle est dans l'intervalle de pause
Function Is-PauseTime {
    $currentTime = Get-Date
    $startPauseTime = Get-Date -Hour 12 -Minute 30
    $endPauseTime = Get-Date -Hour 14 -Minute 0

    return $currentTime -ge $startPauseTime -and $currentTime -le $endPauseTime
}

# Boucle infinie pour simuler une pression de touche périodique
while ($true) {
    if (-not (Is-PauseTime)) {
        Send-KeyPress " "
    }
    
    Start-Sleep -Seconds 300 # Attend 5 minutes avant de répéter
}
