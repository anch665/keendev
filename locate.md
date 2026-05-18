# Установка и настройка locate на Keenetic

## Установка 
```bash
opkg install mlocate
```
## Настройка
### Первичная настройка, добавление групп и установка прав
```bash
chgrp mlocate /opt/var/mlocate
chmod g=rx,o= /opt/var/mlocate
chgrp mlocate /opt/bin/locate
chmod g+s,go-w /opt/bin/locate
touch /opt/var/mlocate/mlocate.db
chgrp mlocate /opt/var/mlocate/mlocate.db
```

### Конфигурационный файл
Создайте файл /opt/etc/updatedb.conf
/mnt/cfef81b2-b7e5-dc01-c0e5-80b2b7e5dc01  - в данном случае флека, что бы не дублировать фалы в результатах
```vim
PRUNEPATHS="/tmp/mnt/cfef81b2-b7e5-dc01-c0e5-80b2b7e5dc01"
```
Добавьте в него пути для исключения каталоги разделяются проблеами
```vim
PRUNEPATHS="/tmp /tmp/mnt/cfef81b2-b7e5-dc01-c0e5-80b2b7e5dc01"
```

## обновление DB
```bash
updatedb
```
