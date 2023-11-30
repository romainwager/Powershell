# Install the Selenium module and MSEdge WebDriver first if not already done
Import-Module Selenium

# Define a function to fetch torrent details
Function Fetch-TorrentDetails {
    param (
        [string]$baseUrl,
        [string[]]$searchParams,
        [string[]]$filterCriteria
    )

    # Start the Edge session
    $EdgeOptions = New-Object OpenQA.Selenium.Edge.EdgeOptions
    $Driver = New-Object OpenQA.Selenium.Edge.EdgeDriver $EdgeOptions

    # Prepare an array to hold all results from all searches
    $allResults = @()

    foreach ($searchParam in $searchParams) {
        $fullUrl = $baseUrl + $searchParam

        # Navigate to the search URL
        $Driver.Navigate().GoToUrl($fullUrl)

        # Let the page load
        Start-Sleep -Seconds 5

        # Find elements that match the criteria
        $elements = $Driver.FindElementsByXPath("//td/div/a[starts-with(@href, '/torrent')]")

        # Prepare an array to hold the detail URLs and titles
        $detailData = @()

        foreach ($element in $elements) {
            $title = $element.GetAttribute('title')
            $matchesAllCriteria = $true
            foreach ($criteria in $filterCriteria) {
                if (-not ($title -like $criteria)) {
                    $matchesAllCriteria = $false
                    break
                }
            }

            if ($matchesAllCriteria) {
                $detailData += [PSCustomObject]@{
                    Title = $title
                    DetailUrl = $element.GetAttribute('href')
                }
            }
        }

        # Navigate to each detail URL and get the magnet link
        foreach ($data in $detailData) {
            $Driver.Navigate().GoToUrl($data.DetailUrl)
            Start-Sleep -Seconds 5

            $magnetElements = $Driver.FindElementsByXPath("//a[contains(@href, 'magnet:?')]")
            if ($magnetElements.Count -gt 0) {
                $magnetLink = $magnetElements[0].GetAttribute('href')

                $allResults += [PSCustomObject]@{
                    SearchParam = $searchParam
                    Title = $data.Title
                    DetailUrl = $data.DetailUrl
                    MagnetLink = $magnetLink
                }
            }
        }
    }

    # Close the browser session
    $Driver.Quit()

    # Return all results
    return $allResults
}

# Define the base URL
$baseUrl = "https://www.oxtorrent.vg/recherche/"

# Define the search parameters
$searchParams = @("S.W.A.T", "Another Show", "Yet Another Show") # Add more search terms as needed

# Define the filter criteria
$filterCriteria = @('*french*', '*S05*') # Add more criteria as needed

# Fetch the torrent details
$results = Fetch-TorrentDetails -baseUrl $baseUrl -searchParams $searchParams -filterCriteria $filterCriteria

# Define the path to save the CSV file
$desktopPath = [Environment]::GetFolderPath("Desktop")
foreach ($searchParam in $searchParams) {
    $criteriaForFileName = ($filterCriteria -join "_") -replace '[^a-zA-Z0-9_]', ''
    $fileName = "${searchParam}_${criteriaForFileName}.csv"
    $fullPath = Join-Path $desktopPath $fileName

    # Filter results for the current searchParam and export to a CSV file
    $results | Where-Object { $_.SearchParam -eq $searchParam } | Export-Csv -Path $fullPath -NoTypeInformation
    Write-Output "Results for $searchParam have been saved to $fullPath"
}
