function Show-Menu {
    param (
        [string]$prompt,
        [string[]]$options
    )

    Write-Host $prompt
    for ($i = 0; $i -lt $options.Length; $i++) {
        Write-Host "$($i+1). $($options[$i])"
    }

    $selectedOption = Read-Host "Enter the number corresponding to your selection (1-$($options.Length)):"
    if ($selectedOption -lt 1 -or $selectedOption -gt $options.Length) {
        Write-Host "Invalid selection. Please try again."
        Show-Menu -prompt $prompt -options $options
    }

    return $selectedOption
}

function Get-GamePath {
    param (
        [string]$game
    )

    switch ($game) {
        "Earth 2150: Escape from the Blue Planet" {
            # Read game path from the registry for Earth 2150 EftBP
            $regPath = "HKLM:\SOFTWARE\WOW6432Node\Topware\Earth 2150\BaseGame\FileSystem"
            $regValueName = "outputdir"
        }
        "Earth 2150: The Moon Project" {
            # Read game path from the registry for Earth 2150 TMP
            $regPath = "HKLM:\SOFTWARE\WOW6432Node\Topware\TheMoonProject\BaseGame\FileSystem"
            $regValueName = "outputdir"
        }
        "Earth 2150: Lost Souls" {
            # Read game path from the registry for Earth 2150 LS
            $regPath = "HKLM:\SOFTWARE\WOW6432Node\Reality Pump\LostSouls\BaseGame\FileSystem"
            $regValueName = "outputdir"
        }
        default {
            Write-Host "Invalid game selection."
            Exit 1
        }
    }

    if (Test-Path -Path $regPath) {
        $gamePath = Get-ItemPropertyValue -Path $regPath -Name $regValueName
        if (-not [string]::IsNullOrWhiteSpace($gamePath)) {
            return $gamePath
        }
    }

    Write-Host "Game path not found in the registry."
    Exit 1
}

function Join-ArrayPath
{
   param([parameter(Mandatory=$true)]
   [string[]]$PathElements) 
   if ($PathElements.Length -eq "0")
   {
     $CombinedPath = ""
   }
   else
   {
     $CombinedPath = $PathElements[0]
     for($i=1; $i -lt $PathElements.Length; $i++)
     {
       $CombinedPath = Join-Path $CombinedPath $PathElements[$i]
     }
  }
  return $CombinedPath
}

function Get-SanitizedPath {
    param (
        [string]$path
    )

    $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
    $sanitizedPath = $path -replace "[$invalidChars]", '-'
    return $sanitizedPath
}

function Get-DestinationPath {
    param (
        [string]$destinationFolder,
        [string]$url
    )

    # Remove the ignored segments from the URL
    foreach ($segment in $ignoreSegments) {
        $url = $url -replace [regex]::Escape($segment), ""
    }

    # Split the URL by directory separator ("/") to create the folder structure
    $urlSegments = $url -split "/"
    $urlSegments = $urlSegments | Where-Object { $_ -ne "" }

    # Sanitize each URL segment to create valid folder names
    $sanitizedSegments = $urlSegments | ForEach-Object { Get-SanitizedPath -path $_ }

    # Combine the destination folder and the sanitized URL segments to form the complete destination path
    $destinationPath = Join-ArrayPath (@($destinationFolder) + $sanitizedSegments)

    # Convert the path to use the correct directory separator for the current platform
    $destinationPath = $destinationPath -replace '\\', [IO.Path]::DirectorySeparatorChar

    # If the file is in the root, the destination path will be the root itself
    if ($sanitizedSegments.Count -eq 0) {
        #$destinationPath = $destinationFolder
    } else {
        # Ensure subfolders exist in the destination path
        $subfolders = $sanitizedSegments | Select-Object -SkipLast 1 | ForEach-Object {
            $destinationFolder = Join-Path $destinationFolder $_
            if (-Not (Test-Path -Path $destinationFolder -PathType Container)) {
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
            }
            $_
        }
        #$destinationPath = $destinationFolder
    }
    
    return $destinationPath
}

try {
    # Load the XML file from the internet
    $xmlUrl = "https://raw.githubusercontent.com/InsideEarth2150/AutoUpdater/main/xmls/Menu/menu.xml"
    $xmlContent = Invoke-WebRequest -Uri $xmlUrl -UseBasicParsing

    # Check if the request was successful
    if ($xmlContent.StatusCode -ne 200) {
        throw "Failed to load XML from the provided URL. Make sure the XML file is accessible."
    }

    # Try parsing the XML content
    try {
        $xml = [xml]$xmlContent.Content
    } catch {
        throw "Failed to parse XML content. Ensure the XML file is correctly formatted."
    }

    # Retrieve available games from XML
    $games = $xml.games.game
    $gameNames = $games | Select-Object -ExpandProperty name
    if (-Not($gameNames -is [array])) {
        $gameNames = @($gameNames)
    }
    $selectedGameIndex = Show-Menu -prompt "Select your game:" -options $gameNames
    $selectedGame = $games[$selectedGameIndex - 1]
    Write-Host "selectedGame: $($selectedGame.name)"
    
    # Retrieve available versions/mods for the selected game and language from XML
    $versions = $selectedGame.version
    if (-Not($versions -is [array])) {
        $versions = @($versions)
    }
    $versionNames = $versions | Select-Object -ExpandProperty name
    if (-Not($versionNames -is [array])) {
        $versionNames = @($versionNames)
    }

    $selectedVersionIndex = Show-Menu -prompt "Select your version or mod:" -options $versionNames
    $selectedVersion = $versions[$selectedVersionIndex - 1]
    Write-Host "selectedVersion: $($selectedVersion.name)"

    # Retrieve available languages for the selected game from XML
    $languages = $selectedVersion.language
    if (-Not($languages -is [array])) {
        $languages = @($languages)
    }
    $languageNames = $languages | Select-Object -ExpandProperty name
    if (-Not($languageNames -is [array])) {
        $languageNames = @($languageNames)
    }
    
    $selectedLanguageIndex = Show-Menu -prompt "Select the game language" -options $languageNames
    $selectedLanguage = $languages[$selectedLanguageIndex - 1]
    Write-Host "selectedLanguage: $($selectedLanguage.name)"

    # Get the game path from the registry
    $gamePath = Get-GamePath -game $selectedGame.name
    Write-Host "gamePath: $gamePath"

    # Find the download URL based on the selected game, language, and version from XML
    $downloadUrl = $selectedLanguage.DownloadUrl

    Write-Host "You selected: $($selectedGame.name), $($selectedVersion.name), $($selectedLanguage.name)"
    Write-Host "Game Path: $gamePath"
    Write-Host "Download URL: $downloadUrl"
    # Here, you can add code to perform the actual download.
    # For simplicity, I'm just showing the game path and download URL.

    # DOWNLOADER part
    $sourceXmlUrl = "$downloadUrl"

    # Create the destination folder if it doesn't exist
    if (-Not (Test-Path -Path $gamePath -PathType Container)) {
        throw "Game directory $gamePath does not exist!"
    }

    # Download the XML file
    $webClient = New-Object System.Net.WebClient
    $xmlData = $webClient.DownloadString($sourceXmlUrl)

    # Load the XML data
    $xmlDoc = [System.Xml.XmlDocument]::new()
    $xmlDoc.LoadXml($xmlData)

    # Extract the URLs and deletion settings from the XML
    $sourceFiles = $xmlDoc.SelectNodes("//urls/url | //urls/delete")

    # Process each URL and deletion setting
    foreach ($item in $sourceFiles) {
        $url = $item.InnerText
        $relativeUrl = $url -replace "^.*\/\d+\.\d+\.\d+\.\d+\/", ""
        if ($item.LocalName -eq "url") {

            # Get the destination path for the current file
            $destinationPath = Get-DestinationPath -destinationFolder $gamePath -url $relativeUrl

            # Extract the file name directly from the URL
            $fileName = [System.IO.Path]::GetFileName($url)

            # Download the file and save it to the destination folder
            try {
                $webClient.DownloadFile($url, $destinationPath)
                Write-Host "Downloaded file: $fileName"
            } catch {
                Write-Host "Error downloading file: $_.Exception.Message"
            }
        } elseif ($item.LocalName -eq "delete") {
            $deletePath = Get-DestinationPath -destinationFolder $gamePath -url $relativeUrl
            if (Test-Path -Path $deletePath -PathType Container) {
                Remove-Item -Path $deletePath -Recurse -Force
                Write-Host "Deleted folder: $deletePath"
            } elseif (Test-Path -Path $deletePath -PathType Leaf) {
                Remove-Item -Path $deletePath -Force
                Write-Host "Deleted file: $deletePath"
            } else {
                Write-Host "File or folder not found: $deletePath"
												   
            }
        }
    }

    Write-Host "All files and folders processed successfully!"
read-host Press ENTER to continue...										  
} catch {
    Write-Host "Error: $_.Exception.Message"
read-host Press ENTER to continue...										  
}

