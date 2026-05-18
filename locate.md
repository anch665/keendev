# Установка и настройка locate на Keenetic

## Установка 
```bash
opkg install mlocate
```
## Настройка
```bash
chgrp mlocate /opt/var/mlocate
chmod g=rx,o= /opt/var/mlocate
chgrp mlocate /opt/bin/locate
chmod g+s,go-w /opt/bin/locate
touch /opt/var/mlocate/mlocate.db
chgrp mlocate /opt/var/mlocate/mlocate.db
```

## обновление DB
```bash
updatedb
```
