# Minecraft Server Generator
> Easy and fast Minecraft server generator<br>
> Automatically install required libraries and<br>
> download servers tailored to the latest version of Minecraft
>

## Docker

### Setup Command
```bash
docker create -it -name minecraft-server -p 25565:25565 \
  ghcr.io/past2l/minecraft-server
```

### Environments
|Environment Name|Description|Default Value|
|:-:|:-:|:-:|
|TZ|Set Timezone|`Asia/Seoul`|
|UID|Set User ID|`1000`|
|GID|Set Group ID|`1000`|
|VERSION|Set Minecraft Version|`latest`|
|RAM|Set Minecraft Server RAM|`4096M`|
|TYPE|Set Minecraft Bukkit Type<br>(`vanilla`, `paper`, `spigot`)|`paper`|
|SERVER_DIRECTORY|Set Minecraft Server Directory|`/mc/app`|
|LIBRARY_DIRECTORY|Set Library Directory|`/mc/lib`|
## Windows

### Setup Command
```batch
.\server.bat
```

### Options
```
  -h, -help                              Show this help and exit
  -v, -version <version>                 Select the Minecraft Server version
  -t, -type <vanilla|paper|spigot>       Select the Bukkit type you want to install
  -r, -ram <ram_size>                    Select the amount of RAM you want to allocate to the server
  -d, -sd, -serverDirectory <directory>  Select the path to install the Minecraft Server
  -ld, -libraryDirectory <directory>     Select the path to install the required libraries
  -u, -update                            Update the script to the latest version
  -remapped                              Select the remapped version of the server
  -forceReplace                          Force replace the existing server file
```
## macOS & Linux

### Setup Command
```batch
chmod +x ./server && ./server
```

### Options
```
  -h, --help                               Show this help and exit
  -v, --version <version>                  Select the Minecraft Server version
  -t, --type <vanilla|paper|spigot>        Select the Bukkit type you want to install
  -r, --ram <ram_size>                     Select the amount of RAM you want to allocate to the server
  -d, -sd, --server-directory <directory>  Select the path to install the Minecraft Server
  -ld, --library-directory <directory>     Select the path to install the required libraries
  -u, --update                             Update the script to the latest version
  --remapped                               Select the remapped version of the server
  --force-replace                          Force replace the existing server file
```
