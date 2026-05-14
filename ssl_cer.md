# Получение SSL-сертификатов на Keenetic (порты для форков без KeenDNS)

Для получения SSL-сертификата от Let's Encrypt на роутере Keenetic с Entware необходимо:

* Наличие **белого (публичного) IP-адреса**. Если IP динамический, используйте любой сервис Dynamic DNS (например, freedns.afraid.org).
* Использование **nginx** в качестве веб-сервера (его настройка в данном руководстве не рассматривается).

## 1. Освобождение порта 443 на роутере

Порт 443 на Keenetic по умолчанию занят внутренними процессами. Переместим встроенный веб-интерфейс на другой порт:
```bash
/bin/ndmc -c "ip http ssl port 4433"
/bin/ndmc -c "system configuration save"
```
Теперь порт 443 свободен для вашего nginx.

## 2. Установка пакетов uacme
```bash
opkg update
opkg install uacme uacme-ualpn
```

## 3. Регистрация аккаунта в Let's Encrypt
```bash
uacme -v -c /opt/etc/ssl/uacme new
```

## 4. Получение сертификата
Важно: переменная CHALLENGE_PATH должна указывать на каталог, доступный через внешний порт 80 для обмена ключами (HTTP-01 challenge). Убедитесь, что nginx обслуживает этот путь.

Для одного домена (с подробным логированием)
```bash
CHALLENGE_PATH="/opt/share/nginx/html/.well-known/acme-challenge" \
uacme -v -c /opt/etc/ssl/uacme -h /opt/share/uacme/uacme.sh issue anch665.my.to
```

Для второго домена
```bash
CHALLENGE_PATH="/opt/share/nginx/html/.well-known/acme-challenge" \
uacme -v -c /opt/etc/ssl/uacme -h /opt/share/uacme/uacme.sh issue anch665.root.sx
```

Для обоих доменов одним запросом (SAN-сертификат)
```bash
CHALLENGE_PATH="/opt/share/nginx/html/.well-known/acme-challenge" \
uacme -v -c /opt/etc/ssl/uacme -h /opt/share/uacme/uacme.sh issue anch665.my.to anch665.root.sx
```

## 5. Где лежат сертификаты и ключи
При успешном выполнении команды вы получите:

* Приватный ключ: /opt/etc/ssl/uacme/private/anch665.my.to/key.pem
* Сертификат: /opt/etc/ssl/uacme/anch665.my.to/cert.pem

## 6. Автоматическое обновление сертификата (cron)
Сертификат выдаётся на 90 дней. Чтобы не пропустить обновление, добавьте задание в cron (например, каждый 1-й день месяца в 3:00):
```bash
0 3 1 * * export CHALLENGE_PATH="/opt/share/nginx/html/.well-known/acme-challenge" && /opt/bin/uacme -y -c /opt/etc/ssl/uacme -h /opt/share/uacme/uacme.sh issue anch665.my.to anch665.root.sx && /opt/etc/init.d/S80nginx reload
```
* Ключ -y автоматически подтверждает challenge (необходимо для работы из cron).
* После успешного обновления сертификата выполняется перезагрузка nginx.


## Примечания
* Убедитесь, что nginx настроен на обслуживание каталога /.well-known/acme-challenge из CHALLENGE_PATH.
* Внешний порт 80 должен быть проброшен на внутренний порт, который слушает nginx (например, 81).
* При ручном запуске с -v вы увидите детальный вывод, включая пути к ключам и статус проверки.
