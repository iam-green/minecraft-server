param (
  [string]$version = "latest",
  [string]$serverDirectory = ".",
  [string]$libraryDirectory = "$env:APPDATA/past2l",
  [string]$ram = "4G",
  [string]$type = "paper",
  [bool]$remapped = $false,
  [bool]$forceReplace = $false
)

$now_location = Get-Location

function Directory_Setting {
  $directory = @($serverDirectory, $libraryDirectory)
  for ($i = 0; $i -lt $directory.Length; $i++) {
    if (-not (Test-Path -Path $($directory[$i]) -PathType Container)) {
      New-Item -Path $($directory[$i]) -ItemType Directory -Force | Out-Null
    }
  }
}

function Get_MC_Version_List {
  return (Invoke-WebRequest -Uri "https://launchermeta.mojang.com/mc/game/version_manifest.json" | ConvertFrom-Json)
}

function Get_MC_Version_Latest {
  return (Get_MC_Version_List).latest.release
}

function Check_Version_Exist {
  param (
    [string]$version_ = $version
  )
  $versionList = (Get_MC_Version_List).versions.id
  if (-not ($versionList -contains $version_)) {
    Exit
  }
}

function Check_Java_Version {
  param (
    [string]$version_ = $version
  )
  foreach ($item in (Get_MC_Version_List).versions) {
    if ($item.id -eq $version_) {
      $version_url = $item.url
      break
    }
  }
  return (Invoke-WebRequest -Uri $version_url | ConvertFrom-Json).javaVersion.majorVersion
}

function Install_Java {
  param (
    [string]$version = $java_version
  )
  $ZULU_VERSIONS = @{
    8 = "zulu8.74.0.17-ca-jre8.0.392"
    16 = "zulu16.32.15-ca-jre16.0.2"
    17 = "zulu17.46.19-ca-jre17.0.9"
    21 = "zulu21.34.19-ca-jre21.0.3"
  }
  if (-not (Test-Path -Path $libraryDirectory/java/$JAVA_VERSION)) {
    curl.exe -sfSLo ./$JAVA_VERSION.zip https://cdn.azul.com/zulu/bin/$($ZULU_VERSIONS[$JAVA_VERSION])-win_x64.zip
    Expand-Archive -Path ./$JAVA_VERSION.zip -DestinationPath $libraryDirectory/java -Force
    Move-Item -Path $libraryDirectory/java/$($ZULU_VERSIONS[$JAVA_VERSION])-win_x64 -Destination $libraryDirectory/java/$JAVA_VERSION -Force
    Remove-Item -Path ./$JAVA_VERSION.zip -Recurse -Force
  }
}

function Get_Server_File {
  param (
    [string]$version_ = $version,
    [string]$type_ = $type,
    [bool]$remapped_ = $remapped
  )
  if ($forceReplace) {
    Remove-Item -Path $serverDirectory/server.jar -Recurse -Force
  }
  if ((Test-Path -Path $serverDirectory/server.jar) -and (Test-Path -Path $serverDirectory/bukkit.json)) {
    $before = Get-Content -Path $serverDirectory/bukkit.json | ConvertFrom-Json
    if ($before.version -ne $version_ -or $before.remapped -ne $remapped_ -or $before.type -ne $type_) {
      Remove-Item -Path $serverDirectory/server.jar -Recurse -Force
    }
  }
  if (Test-Path -Path $serverDirectory/server.jar) {
    return
  }
  switch ($type_) {
    "vanilla" {
      $remapped_=false
      foreach ($item in (Get_MC_Version_List).versions) {
        if ($item.id -eq $version_) {
          $version_url = $item.url
          break
        }
      }
      $url = (Invoke-WebRequest -Uri $version_url | ConvertFrom-Json).downloads.server.url
      if ($url -eq $null) {
        Write-Host "Vanilla Server does not support this version."
        Exit
      } else {
        curl.exe -sfSLo $serverDirectory/server.jar $url
      }
    }
    "paper" {
      $response = Invoke-WebRequest -Uri "https://papermc.io/api/v2/projects/paper/versions/$version_" -Method Head
      if ($response.StatusCode -ne 200) {
        Write-Host "Paper Server does not support this version."
        Exit
      }
      $build_id = (Invoke-WebRequest -Uri "https://papermc.io/api/v2/projects/paper/versions/$version_" | ConvertFrom-Json).builds[-1]
      if ($remapped_) {
        $mojmap = "-mojmap"
      } else {
        $mojmap = ""
      }
      $url = "https://papermc.io/api/v2/projects/paper/versions/$version_/builds/$build_id/downloads/paper$mojmap-$version_-$build_id.jar"
      $response = Invoke-WebRequest -Uri $url -Method Head
      if ($response.StatusCode -ne 200) {
        Write-Host "PaperMC Server File could not be downloaded."
        Exit
      } else {
        curl.exe -sfSLo $serverDirectory/server.jar $url
      }
    }
    "spigot" {
      $url = "https://download.getbukkit.org/spigot/spigot-$version_.jar"
      $response = Invoke-WebRequest -Uri $url -Method Head
      if ($response.StatusCode -ne 200) {
        Write-Host "Spigot Server does not support this version."
        Exit
      } else {
        curl.exe -sfSLo $serverDirectory/server.jar $url
      }
    }
    default {
      Write-Host "Invaild Bukkit type."
      Exit
    }
  }
  if ($remapped_) {
    $remapped_text = "true"
  } else {
    $remapped_text = "false"
  }
  "{`"type`":`"$type_`",`"version`":`"$version_`",`"remapped`":$remapped_text}" | Set-Content -Path $serverDirectory/bukkit.json -Force
}

function Start_Server {
  param (
    [string]$version_ = $version,
    [string]$ram_ = $ram
  )
  Set-Location -Path $serverDirectory
  "eula=true" | Set-Content -Path eula.txt -Force
  Invoke-Expression "$libraryDirectory/java/$java_version/bin/java.exe -Xms$ram_ -Xmx$ram_ -jar server.jar nogui" 
  Set-Location -Path $now_location
}

$serverDirectory = Resolve-Path -Path $serverDirectory
$libraryDirectory = Resolve-Path -Path $libraryDirectory
Directory_Setting

if ($version -eq "latest") {
  $version = Get_MC_Version_Latest
}

Check_Version_Exist $version
$java_version = Check_Java_Version $version
Install_Java $java_version
Get_Server_File $version $type $remapped
Start_Server $version $ram