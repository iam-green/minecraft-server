param (
  [string]$version = "latest",
  [string]$serverDirectory = ".",
  [string]$libraryDirectory = "$env:APPDATA/iam-green",
  [string]$ram = "4G",
  [string]$type = "paper",
  [switch]$remapped,
  [switch]$forceReplace,
  [switch]$help,
  [switch]$update,
  [string]$v,
  [string]$d,
  [string]$sd,
  [string]$ld,
  [string]$r,
  [string]$t,
  [switch]$h,
  [switch]$u
)

function Directory_Setting {
  $directory = @($serverDirectory, $libraryDirectory)
  for ($i = 0; $i -lt $directory.Length; $i++) {
    if (-not (Test-Path -Path $($directory[$i]) -PathType Container)) {
      New-Item -Path $($directory[$i]) -ItemType Directory -Force | Out-Null
    }
  }
}

function Get_MC_Version_List {
  return (curl.exe -s "https://launchermeta.mojang.com/mc/game/version_manifest.json" | ConvertFrom-Json)
}

function Get_MC_Version_Latest { return (Get_MC_Version_List).latest.release }

function Get_MC_Version_Snapshot { return (Get_MC_Version_List).latest.snapshot }

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
  return (curl.exe -s $version_url | ConvertFrom-Json).javaVersion.majorVersion
}

function Get_Java_File_Name {
  param (
    [string]$version_ = $version
  )
  $name = (curl.exe -s "https://api.azul.com/metadata/v1/zulu/packages/?java_version=$version_&os=windows&arch=amd64&java_package_type=jre&page=1&page_size=1&release_status=ga&availability_types=CA&certifications=tck&archive_type=zip" | ConvertFrom-Json)[0].name
  return $name -replace '.zip'
}

function Install_Java {
  param (
    [string]$version = $java_version
  )
  $java_name = Get_Java_File_Name $version
  if (-not (Test-Path -Path $libraryDirectory/java/$JAVA_VERSION)) {
    curl.exe -sfSLo ./$JAVA_VERSION.zip https://cdn.azul.com/zulu/bin/$java_name.zip
    Expand-Archive -Path ./$JAVA_VERSION.zip -DestinationPath $libraryDirectory/java -Force
    Move-Item -Path $libraryDirectory/java/$java_name -Destination $libraryDirectory/java/$JAVA_VERSION -Force
    Remove-Item -Path ./$JAVA_VERSION.zip -Recurse -Force
  }
}

function Get_Server_File {
  param (
    [string]$version_ = $version,
    [string]$type_ = $type,
    [switch]$remapped_ = $remapped
  )
  if ((($forceReplace -or (Test-Path -Path $serverDirectory/bukkit.json)) -or (Test-Path -Path $serverDirectory/server.jar))) {
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
      $remapped_=$false
      foreach ($item in (Get_MC_Version_List).versions) {
        if ($item.id -eq $version_) {
          $version_url = $item.url
          break
        }
      }
      $url = (curl.exe -s $version_url | ConvertFrom-Json).downloads.server.url
      if ($null -eq $url) {
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
      $build_id = (curl.exe -s  "https://papermc.io/api/v2/projects/paper/versions/$version_" | ConvertFrom-Json).builds[-1]
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
  Invoke-Expression "$libraryDirectory/java/$java_version/bin/java.exe -Xmx$ram_ -jar server.jar nogui" 
  Set-Location -Path $now_location
}

if ($help -or $h) {
  Write-Host "Options:"
  Write-Host " -h, -help                              Show this help and exit"
  Write-Host " -v, -version <version>                 Select the Minecraft Server version"
  Write-Host " -t, -type <vanilla|paper|spigot>       Select the Bukkit type you want to install"
  Write-Host " -r, -ram <ram_size>                    Select the amount of RAM you want to allocate to the server"
  Write-Host " -d, -sd, -serverDirectory <directory>  Select the path to install the Minecraft Server"
  Write-Host " -ld, -libraryDirectory <directory>     Select the path to install the required libraries"
  Write-Host " -u, -update                            Update the script to the latest version"
  Write-Host " -remapped                              Select the remapped version of the server"
  Write-Host " -forceReplace                          Force replace the existing server file"
  Exit
}

if ($update -or $u) {
  curl.exe -sfSLo .\server.ps1 "https://raw.githubusercontent.com/iam-green/minecraft-server/main/server.ps1"
  Write-Host "The update is complete, please re-run the code."
  exit
}

$now_location = Get-Location

if ($v) { $version = $v }
if ($d) { $serverDirectory = $d }
if ($sd) { $serverDirectory = $sd }
if ($ld) { $libraryDirectory = $ld }
if ($r) { $ram = $r }
if ($t) { $type = $t }

Directory_Setting
$serverDirectory = Resolve-Path -Path $serverDirectory
$libraryDirectory = Resolve-Path -Path $libraryDirectory

if ($version -eq "latest") { $version = Get_MC_Version_Latest }
if ($version -eq "snapshot") {
  $type = "vanilla"
  $version = Get_MC_Version_Snapshot
  $remapped = $false
}

Check_Version_Exist $version
$java_version = Check_Java_Version $version
Install_Java $java_version
Get_Server_File $version $type $remapped
Start_Server $version $ram
