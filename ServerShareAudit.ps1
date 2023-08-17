# Import the Active Directory module
Import-Module ActiveDirectory

# Define the maximum concurrent jobs allowed
$maxConcurrentJobs = 10
$jobs = @()
$currentIndex = 0

# Get all the computers from the specified OU
$computerNames = Get-ADComputer -Filter 'OperatingSystem -like "*Windows*"' -SearchBase "DC=hivetech,DC=com" -Properties Name | Select-Object -ExpandProperty Name

# Scriptblock to execute remotely
$scriptBlock = {
    $results = @()

    # List of administrative shares to ignore based on alphabet letters
    $adminShares = ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') | ForEach-Object { "$_`$" }
    $adminShares += @("IPC$", "ADMIN$", "ClusterStorage$", 'print$')

    # Retrieve the shares for the current server
    $shares = Get-WmiObject -Class Win32_Share

    foreach ($share in $shares) {
        # Extract the share name
        $splitName = $share.Name -split '\\'
        $serverName = if ($splitName.Count -ge 3) { $splitName[2] } else { $env:ComputerName }
        $shareName = if ($splitName.Count -ge 1) { $splitName[-1] } else { $env:ComputerName }

        # Ignore the specified administrative shares
        if ($adminShares -notcontains $shareName) {
            # Retrieve the share permissions for the current share
            $permissions =  Get-SmbShareAccess -Name $shareName -ErrorAction SilentlyContinue

            foreach ($perm in $permissions) {
                $results += [PSCustomObject]@{
                    "Server"     = $serverName
                    "ShareName"  = $shareName
                    "Path"       = $share.Path
                    "Description"= $share.Description
                    "Username"   = $perm.AccountName
                    "Permission" = $perm.AccessRight
                }
            }
        }
    }
    return $results
}

# Filter the computers to keep only the reachable ones
$reachableComputers = $computerNames | Where-Object {
    try {
        # Attempt a quick ping
        Test-Connection -ComputerName $_ -Count 1 -ErrorAction Stop | Out-Null
        $true
    } catch {
        $false
    }
}

# Manage job execution ensuring we don't exceed maximum concurrent jobs
while ($currentIndex -lt $reachableComputers.Count) {
    # Get currently running jobs
    $runningJobs = $jobs | Where-Object { $_.State -eq "Running" }
    
    # If the number of running jobs is less than the maximum allowed, start new ones
    while ($runningJobs.Count -lt $maxConcurrentJobs -and $currentIndex -lt $reachableComputers.Count) {
        $job = Invoke-Command -ComputerName $reachableComputers[$currentIndex] -ScriptBlock $scriptBlock -AsJob
        $jobs += $job
        $currentIndex++
        $runningJobs = $jobs | Where-Object { $_.State -eq "Running" }
    }

    # Wait a bit before checking again
    Start-Sleep -Seconds 5
}

# Wait for all jobs to complete
$jobs | Wait-Job

# Collect results from jobs and save to CSV
$results = $jobs | ForEach-Object {
    Receive-Job -Job $_
}

$results | Select-Object Server, ShareName, Path, Description, Username, Permission | Export-Csv -Path 'ServerShareAudit.csv' -NoTypeInformation -Delimiter ";" -Encoding 'UTF8'

# Cleanup after retrieving results
$jobs | Remove-Job
