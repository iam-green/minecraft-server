param (
  [string]$version = "latest",
  [string]$modVersion = "recommend",
  [string]$serverDirectory = ".",
  [string]$libraryDirectory,
  [string]$serverFile = "server.jar",
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
  [string]$m,
  [switch]$h,
  [switch]$u
)

$global:modVersion = $modVersion

$os = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription

function Get-OS {
  if ($os -match "Windows") {
    return "windows"
  } elseif ($os -match "Darwin") {
    return "macos"
  } else {
    return "linux"
  }
}

function Get-Arch {
  if ($os -match "Windows") {
    $architecture = (Get-WmiObject -Class Win32_Processor).Architecture
    switch ($architecture) {
      9 { return "amd64" }
      5 { return "arm64" }
      default {
        Write-Output "This architecture is not supported."
        exit 1
      }
    }
  } else {
    $architecture = (uname -m)
    switch ($architecture) {
      "x86_64" { return "amd64" }
      {$_ -in @("arm64", "aarch64")} { return "arm64" }
      default {
        Write-Output "This architecture is not supported."
        exit 1
      }
    }
  }
}

function Get-Home {
  if ($os -match "Windows") {
    return $env:USERPROFILE
  } else {
    return $env:HOME
  }
}

function Use-Curl {
  param (
    [string]$url
  )
  if ($os -match "Windows") {
    return (curl.exe -s $url)
  } else {
    return (curl -s $url)
  }
}

function Use-Curl-Download {
  param (
    [string]$output,
    [string]$url
  )
  if ($os -match "Windows") {
    curl.exe -sfSLo $output $url
  } else {
    curl -sfSLo $output $url
  }
}

function Directory-Setting {
  param (
    [ref] $serverDirectory,
    [ref] $libraryDirectory
  )
  if (-not $libraryDirectory.Value) {
    $libraryDirectory.Value = "$(Get-Home)/.iam-green"
  }
  $directory = @($serverDirectory.Value, $libraryDirectory.Value)
  for ($i = 0; $i -lt $directory.Length; $i++) {
    if (-not (Test-Path -Path $($directory[$i]) -PathType Container)) {
      New-Item -Path $($directory[$i]) -ItemType Directory -Force | Out-Null
    }
  }
  $serverDirectory.Value = Resolve-Path -Path $serverDirectory.Value
  $libraryDirectory.Value = Resolve-Path -Path $libraryDirectory.Value
}

function Get-MC-Manifest {
  return (Use-Curl "https://launchermeta.mojang.com/mc/game/version_manifest.json")
}

function Get-MC-Version-List {
  return (Get-MC-Manifest | ConvertFrom-Json)
}

function Get-MC-Version-Latest {
  return (Get-MC-Manifest | ConvertFrom-Json).latest.release
}

function Get-MC-Version-Snapshot {
  return (Get-MC-Manifest | ConvertFrom-Json).latest.snapshot
}

function Check-Java-Version {
  param (
    [string]$v = $version
  )
  foreach ($item in (Get-MC-Manifest | ConvertFrom-Json).versions) {
    if ($item.id -eq $v) {
      $version_url = $item.url
      break
    }
  }
  return (Use-Curl $version_url | ConvertFrom-Json).javaVersion.majorVersion
}

function Check-Version-Exist {
  param (
    [string]$v = $version
  )
  $versionList = (Get-MC-Manifest | ConvertFrom-Json).versions.id
  if (-not ($versionList -contains $v)) {
    Write-Output "This Minecraft version could not be found."
    exit 1
  }
}

function Install-Java {
  param (
    [string]$v,
    [string]$os = (Get-OS),
    [string]$arch = (Get-Arch)
  )
  $name = (Use-Curl "https://api.azul.com/metadata/v1/zulu/packages/?java_version=$v&os=$os&arch=$arch&java_package_type=jre&page=1&page_size=1&release_status=ga&availability_types=CA&certifications=tck&archive_type=zip" | ConvertFrom-Json)[0].name
  $java_name = $name -replace '.zip'
  if (-not (Test-Path -Path $libraryDirectory/java/$v)) {
    Use-Curl-Download $libraryDirectory/java_$v.zip https://cdn.azul.com/zulu/bin/$java_name.zip
    Expand-Archive -Path $libraryDirectory/java_$v.zip -DestinationPath $libraryDirectory/java -Force
    Move-Item -Path $libraryDirectory/java/$java_name -Destination $libraryDirectory/java/$v -Force
    Remove-Item -Path $libraryDirectory/java_$v.zip -Recurse -Force
  }
}

function Download-Vanilla-Server {
  param (
    [string]$v = $version
  )
  foreach ($item in (Get-MC-Version-List).versions) {
    if ($item.id -eq $v) {
      $version_url = $item.url
      break
    }
  }
  $url = (Use-Curl $version_url | ConvertFrom-Json).downloads.server.url
  if ($null -eq $url) {
    Write-Host "Vanilla Server does not support this minecraft version."
    exit
  } else {
    Use-Curl-Download $serverDirectory/$serverFile $url
  }
}

function Download-Paper-Server {
  param (
    [string]$v = $version,
    [switch]$re = $remapped
  )
  $res = Invoke-WebRequest -Uri "https://api.papermc.io/v2/projects/paper/versions/$v" -Method Head
  if ($res.StatusCode -ne 200) {
    Write-Host "PaperMC Server does not support this minecraft version."
    exit
  }
  $build_id = (Use-Curl "https://api.papermc.io/v2/projects/paper/versions/$v" | ConvertFrom-Json).builds[-1]
  if ($re) { $mojmap = "-mojmap" } else { $mojmap = "" }
  Use-Curl-Download $serverDirectory/$serverFile "https://api.papermc.io/v2/projects/paper/versions/$v/builds/$build_id/downloads/paper$mojmap-$v-$build_id.jar"
}

function Get-Forge-Version {
  param (
    [string]$v = $version
  )
  $content = Use-Curl "https://files.minecraftforge.net/net/minecraftforge/forge/index_$v.html"
  if ($global:modVersion -eq "recommend") {
    if ($content | Select-String -Pattern "Recommended: ") {
      $global:modVersion = $content | Select-String -Pattern '(?<=Recommended: )(.*?)(?=")' -AllMatches
      $global:modVersion = $global:modVersion -replace '^Recommended: ', ''
      $global:modVersion = $global:modVersion -replace '"/>$', ''
    } else {
      $global:modVersion = "latest"
    }
  }
  if ($global:modVersion -eq "latest") {
    $global:modVersion = $content | Select-String -Pattern '(?<=Latest: )(.*?)(?=")' -AllMatches
    $global:modVersion = $global:modVersion -replace '^Latest: ', ''
    $global:modVersion = $global:modVersion -replace '"/>$', ''
  }
  if (-not ($content | Select-String -Pattern "-$v-$global:modVersion-")) {
    Write-Host "Forge does not support this minecraft version."
    exit
  }
}

function Download-Forge-Server {
  param (
    [string]$v = $version
  )
  Use-Curl-Download $serverDirectory/forge_installer.jar "https://maven.minecraftforge.net/net/minecraftforge/forge/$v-$global:modVersion/forge-$v-$global:modVersion-installer.jar"
  if ($os -match "Windows") { $java = "java.exe" } else { $java = "java" }
  Invoke-Expression "$libraryDirectory/java/$(Check-Java-Version $v)/bin/$java -jar $serverDirectory/forge_installer.jar --installServer $serverDirectory" | Out-Null
  Remove-Item -Path $serverDirectory/forge_installer.jar -Recurse -Force
  Remove-Item -Path ./forge_installer.jar.log -Recurse -Force
}

function Get-Fabric-Version {
  param (
    [string]$m = $version
  )
  if ($global:modVersion -eq "latest" -or $global:modVersion -eq "recommend") {
    $global:modVersion = (curl.exe -s "https://meta.fabricmc.net/v2/versions/loader" | ConvertFrom-Json)[0].version
  }
  $loaders = (curl.exe -s "https://meta.fabricmc.net/v2/versions/loader" | ConvertFrom-Json)
  if (-not ($loaders | Where-Object { $_.version -eq $global:modVersion })) {
    Write-Host "Fabric Loader does not support this version."
    exit
  }
}

function Download-Fabric-Server {
  param (
    [string]$v = $version
  )
  $installer_version = (Use-Curl "https://meta.fabricmc.net/v2/versions/installer" | ConvertFrom-Json)[0].version
  Write-Host "https://meta.fabricmc.net/v2/versions/loader/$v/$global:modVersion/$installer_version/server/jar"
  Use-Curl-Download $serverDirectory/$serverFile "https://meta.fabricmc.net/v2/versions/loader/$v/$global:modVersion/$installer_version/server/jar"
}

function Get-Server-File {
  param (
    [string]$t = $type,
    [string]$v = $version,
    [switch]$r = $remapped
  )
  switch ($t) {
    "forge" { Get-Forge-Version }
    "fabric" { Get-Fabric-Version }
    default {}
  }
  if ($forceReplace) {
    Remove-Item -Path $serverDirectory/$serverFile -Recurse -Force
    Remove-Item -Path $serverDirectory/libraries -Recurse -Force
  }
  if (($type -eq "forge" -and (Test-Path -Path "$serverDirectory/libraries/net/minecraftforge/forge/$v-$global:modVersion")) -or (Test-Path -Path $serverDirectory/$serverFile)) {
    return
  }
  switch ($t) {
    "vanilla" { Download-Vanilla-Server $v }
    "paper" { Download-Paper-Server $v $r }
    "fabric" { Download-Fabric-Server $v }
    "forge" { Download-Forge-Server $v }
    default {
      Write-Host "Invaild Bukkit type."
      exit
    }
  }
}

function Start-Server {
  param (
    [string]$t = $type,
    [string]$jv = (Check-Java-Version $version),
    [string]$v = $version,
    [string]$r = $ram
  )
  $now_location = Get-Location
  Set-Location -Path $serverDirectory
  "eula=true" | Set-Content -Path eula.txt -Force
  if ($os -match "Windows") { $java = "java.exe" } else { $java = "java" }
  if ($t -eq "forge" -and (Test-Path -Path $serverDirectory/run.sh)) {
    $arg = "@libraries/net/minecraftforge/forge/$v-$global:modVersion/unix_args.txt"
  } else {
    $arg = "-jar $serverFile"
  }
  Invoke-Expression "$libraryDirectory/java/$jv/bin/$java -Xmx$r $arg nogui" 
  Set-Location -Path $now_location
}

if ($help -or $h) {
  Write-Host "Options:"
  Write-Host " -h, -help                              Show this help and exit"
  Write-Host " -v, -version <version>                 Select the Minecraft Server version"
  Write-Host " -v, -modVersion <version>              Select the Minecraft Mod Server version"
  Write-Host " -t, -type <vanilla|paper|spigot|forge> Select the Bukkit type you want to install"
  Write-Host " -r, -ram <ram_size>                    Select the amount of RAM you want to allocate to the server"
  Write-Host " -d, -sd, -serverDirectory <directory>  Select the path to install the Minecraft Server"
  Write-Host " -ld, -libraryDirectory <directory>     Select the path to install the required libraries"
  Write-Host " -u, -update                            Update the script to the latest version"
  Write-Host " -remapped                              Select the remapped version of the server"
  Write-Host " -forceReplace                          Force replace the existing server file"
  exit
}

if ($update -or $u) {
  Use-Curl-Download ./server.ps1 "https://raw.githubusercontent.com/iam-green/minecraft-server/main/server.ps1"
  Write-Host "The update is complete, please re-run the code."
  exit
}

if ($v) { $version = $v }
if ($d) { $serverDirectory = $d }
if ($sd) { $serverDirectory = $sd }
if ($ld) { $libraryDirectory = $ld }
if ($r) { $ram = $r }
if ($t) { $type = $t }
if ($m) { $modVersion = $m }

if ($version -eq "latest") { $version = Get-MC-Version-Latest }
if ($version -eq "snapshot") {
  $type = "vanilla"
  $version = Get-MC-Version_Snapshot
}
if ($type -ne "paper") { $remapped = $false }

Directory-Setting ([ref]$serverDirectory) ([ref]$libraryDirectory)
Check-Version-Exist $version
$java_version = Check-Java-Version $version
Install-Java $java_version
Get-Server-File
Start-Server
