# Docker-SuperTransfer2
Dockerised SuperTransfer 2 from https://github.com/flicker-rate/SuperTransfer2.

To run: 
```docker run -d --name rclone -e PUID=501 -e PGID=12 -e TZ=Australia\Brisbane -e gdsaImpersonate=(email) -e teamDrive=(tdrive id) -v /config/folder/host:/config -v /uploadstuff/folder/host:/move -v /jsons/folder/host:/jsons docker-st2```