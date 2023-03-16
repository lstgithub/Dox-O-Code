# Variables description for fast start is in the readme file

# If any error occurs, execution of the script will be stopped
$ErrorActionPreference = "Stop";

# Payload for notifications. Variables can be freely adjusted
$request_body = @"
{
  "@context": "https://schema.org/extensions",
  "@type": "MessageCard",
  "themeColor": "status_color",
  "summary": "finished",
  "sections": [
    {
      "activityTitle": "Update from $env:JOB_NAME",
      "activitySubtitle": "Build $env:BUILD_NUMBER finished",
      "facts": [
        {
          "name": "Status:",
          "value": "build_status"
        },
        {
          "name": "Document:",
          "value": "$env:Document"
        },
        {
          "name": "Branch:",
          "value": "$env:Branch"
        },
        {
          "name": "Job started by:",
          "value": "$env:BUILD_USER"
        }
      ]
    }
  ],
  "potentialAction": [
    {
      "@type": "OpenUri",
      "name": "Learn more",
      "targets": [
        {
          "os": "default",
          "uri": "$env:BUILD_URL"
        }
      ]
    }
  ]
}
"@

# Main executable files and libraries location
$env:Path += ";$env:WORKSPACE\Root\Tools\Miktex\texmfs\install\miktex\bin\x64"
$env:Path += ";$env:WORKSPACE\Root\Tools\Pandoc"

# Here goes your remote shared drive authentication
$secpasswd = ConvertTo-SecureString "$env:ACCOUNT" -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ("ACCOUNT", $secpasswd)
Write-Host "Creating temporary mapped network drive"
New-PSDrive -Name "Storage" -PSProvider "FileSystem" -Root "PATH" -Credential $mycreds

# Cleaning temp folders from the previous launches
Write-Host "Checking for temporary files"
$PathTemp = Test-Path -Path "$env:WORKSPACE\tex2pdf*"
if ($PathTemp) {
  Write-Host "Deleting temporary files"
  Remove-Item -Recurse "$env:WORKSPACE\tex2*"
}
elseif (!$PathTemp) {
  Write-Host "No temporary files detected"
}

# To avoid redownloading tools each time, here is a check for their presence
Write-Host "Checking for Pandoc and MikTeX"
$PathTools = Test-Path -Path "$env:WORKSPACE\Root\Tools"
if (!$PathTools) {
  Write-Host "Tools were not found, downloading and extracting"
  Copy-Item -Path 'PATH_TO_TOOLS'
  Expand-Archive Tools.zip -Force
}
elseif ($PathTools) {
  Write-Host "Tools were found, proceeding"
}

# Temporary folder for further preprocessing
$tempFolder = "TempFolder"
$isExist = Test-Path -Path $env:WORKSPACE\$tempFolder
if (!$isExist) {
  mkdir $env:WORKSPACE\$tempFolder
}
else {
  Write-Host "Deleting more temporary files"
  Remove-Item -Recurse -Path "$env:WORKSPACE\$tempFolder"
  mkdir $env:WORKSPACE\$tempFolder
}

# Handler for reusable text parts
# Parent document with a pattern ~Some_reused_text~
# Will be replaced onto content of the Some_reused_text.md file in the repository root
try {
  # Variable to work only with specific documents set
  $ext = $env:Extension
  $mainFiles = Get-ChildItem -Recurse -Path "$env:WORKSPACE\*$ext*\*$ext*.md"
  # Symbol to detect reusable text inside of the main documents
  $serviceSymbol = "~"
  # A cycle to iterate through each document and collect all reusable parts if present
  foreach ($mainFile in $mainFiles) {
    $tempKeyWordList = Get-Content $mainFile | Select-String -Pattern "$serviceSymbol*$serviceSymbol"
    if ($tempKeyWordList.Count -gt 0) {
      $keyWords = $tempKeyWordList -Replace $serviceSymbol
      $content = Get-Content $mainFile

      # Replacement procedure
      foreach ($replacement in $keyWords) {
        $fullContent = Get-Content "$env:WORKSPACE\*$replacement*" -Raw
        $content = $content -Replace $replacement, $fullContent
        $content = $content -Replace $serviceSymbol
      }
      Write-Host "Found MD with replacement parts, building full version"
      $fileName = [System.IO.Path]::GetFileName("$env:WORKSPACE\*$ext*\$mainFile")
      Set-Content -Path $env:WORKSPACE\$tempFolder\Full_$fileName -Value $content
      Set-Location $env:WORKSPACE\$tempFolder
    }

    # Fallback for documents, where no reusable parts are present
    else {
      Write-Host "Found MD without replacement parts"
      Set-Location $env:WORKSPACE\$ext
      Copy-Item *.md -Destination $env:WORKSPACE\$tempFolder
    }
  }

  # Detecting temporary files, used in preprocessing for building full versions
  Set-Location $env:WORKSPACE\$tempFolder
  $prePreFilesToBeRemoved = Get-ChildItem -Recurse -Include "Full_*"
  if ($prePreFilesToBeRemoved.Count -gt 0) {
    $preFilesToBeRemoved = New-Object -TypeName 'System.Collections.ArrayList'
    foreach ($file in $prePreFilesToBeRemoved) {
      $preFilesToBeRemoved.Add([System.IO.Path]::GetFileName($file))
    }
    # Returning the original name
    $filesToBeRemoved = $preFilesToBeRemoved -Replace "Full_*"
    # Deleting previously collected files
    Remove-Item * -Include $filesToBeRemoved
  }

  # Handler for images from relative and friendly to absolute for Pandoc
  # ![**Image description**](./Folder/Image.png) - source
  # ![**Image description**](D:\Folder\Folder\Image.png) - after handling
  $filesList = Get-ChildItem -Recurse -Path "$env:WORKSPACE\$tempFolder\*.md"
  foreach ($file in $filesList) {
    # Collecting images by wildcard
    $preImagePath = Get-Content "$file" | Select-String -Pattern "\./.*\.png"
    # Preprocessing found images
    $imagePath = $preImagePath -Replace ".*\(" -Replace "\)" -Replace ".*\{" -Replace "\}.*"
    $newContent = Get-Content $file
    # Processing of shared and unique images
    foreach ($image in $imagePath) {
      if ($image -Match ".*SharedImages.*") {
        $newImage = $image -Replace "\./", "$env:WORKSPACE/"
      }
      elseif ($image -NotMatch ".*SharedImages.*") {
        $newImage = $image -Replace "\./", "$env:WORKSPACE/$ext/"
      }
      $newImage = $newImage -Replace "\\", "/"
      $newContent = $newContent -Replace $image, $newImage
    }
    $fileName = [System.IO.Path]::GetFileName($file)
    Set-Content -Path ".\$fileName" -Value $newContent
  }

  # A command to Pandoc to convert all MD files in the directory to PDF ones after all preprocessing stages for final documents versions
  Get-ChildItem -r -i *.md | ForEach-Object { $pdf = $_.directoryname + "\" + $_.basename + ".pdf"; pandoc $_.name --pdf-engine=xelatex -o $pdf }
}

catch {
  # Notification about building process failure
  Write-Host $_
  $build_status = "Build failed"
  $status_color = "#ff0000"
  $request_body = $request_body -Replace "build_status", $build_status
  $request_body = $request_body -Replace "status_color", $status_color
  Invoke-RestMethod -Uri "WEB_HOOK_ADDRESS" -Method POST -Body $request_body
  exit 1
}

# Example of custom path for uploading output PDF files, based on the variables from Jenkins job
Write-Host "Documentation is ready"
try {
  if ($env:ANY_VARIABLE -eq "ANY REQUIRED VALUE") {
    Write-Host("Some action description with different destination1")
    New-Item -ItemType Directory -Force -Path "PATH\$env:BUILD_NUMBER"
    Copy-Item *.pdf -Destination "PATH\$env:BUILD_NUMBER"
  }
  else {
    Write-Host("Some action description with different destination2")
    Copy-Item *.pdf -Destination "PATH\$env:Extension"
  }
}

# Notification about failure of PDFs upload to shared drive
catch {
  Write-Host $_
  $build_status = "Can\'t upload files"
  $status_color = "#f2ff00"
  $request_body = $request_body -Replace "build_status", $build_status
  $request_body = $request_body -Replace "status_color", $status_color
  Invoke-RestMethod -Uri "WEB_HOOK_ADDRESS" -Method POST -Body $request_body
  exit 1
}

# Successful build notification
$build_status = "Build success"
$status_color = "#1fc90c"
$request_body = $request_body -Replace "build_status", $build_status
$request_body = $request_body -Replace "status_color", $status_color
Invoke-RestMethod -Uri "WEB_HOOK_ADDRESS" -Method POST -Body $request_body