# Получение SSL-сертификатов на Keenetic (порты для форков без KeenDNS)

Для получения SSL-сертификата от Let's Encrypt на роутере Keenetic с Entware необходимо:

* Наличие **белого (публичного) IP-адреса**. Если IP динамический, используйте любой сервис Dynamic DNS (например, freedns.afraid.org).
* Использование **nginx** в качестве веб-сервера [Ппример конфигурации](#конфигурация-nginx)

## 1. Освобождение порта 443 на роутере

Порт 443 на Keenetic по умолчанию занят внутренними процессами. Переместим встроенный веб-интерфейс на другой порт:
```bash
/bin/ndmc -c "ip http ssl port 4433"
/bin/ndmc -c "system configuration save"
```
Теперь порт 443 свободен для вашего nginx.
В интерфейсе роутера необходио настроить переадрессацию портов в разделе Переадресация портов

| Описание | Вход | Выход | Протокол | Тип правила | Открыть порт | Направлять на порт |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| http  | интерфейс провайдера | Это устройство Keenetic | TCP | Одиночный порт | 80 | 81 |
| https | интерфейс провайдера | Это устройство Keenetic | TCP | Одиночный порт | 443 | 443 |

Описание и порт направления можете указать из своего конфига nginx

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

## nginx

### Установка nginx
```bash
opkg update
opkg install ca-certificates nginx-ssl
```

### Конфигурация nginx
* /opt/etc/nginx/nginx.conf
```bash
user nobody;
worker_processes  1;


events {
    worker_connections  64;
}


http {
    include       mime.types;
    default_type  application/octet-stream;
    include /opt/etc/nginx/conf.d/*.conf;

    sendfile        on;

    keepalive_timeout  65;


}
```

* /opt/etc/nginx/conf.d/anch665.my.to.conf
```
# HTTP-сервер на порту 81 (внешний 80)

server {
    listen 81;
    server_name anch665.my.to anch665.root.sx;

    # access_log /tmp/log/nginx/anch665-http.access.log;
    # error_log  /tmp/log/nginx/anch665-http.error.log;

    # Специальный location для Let's Encrypt проверок
    location ^~ /.well-known/acme-challenge/ {
        root /opt/share/nginx/html;
        # Не перенаправлять эти запросы на HTTPS
    }

    # Всё остальное перенаправляем на HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS-сервер на порту 443
server {
    listen 443 ssl;
    server_name anch665.my.to anch665.root.sx;

    # access_log /tmp/log/nginx/anch665-https.access.log;
    # error_log  /tmp/log/nginx/anch665-https.error.log;

    ssl_certificate     /opt/etc/ssl/uacme/anch665.my.to/cert.pem;
    ssl_certificate_key /opt/etc/ssl/uacme/private/anch665.my.to/key.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root /opt/share/nginx/html;
    index index.html index.htm;

    # Закрываем доступ к .well-known по HTTPS (возвращаем 404)
    location ^~ /.well-known/acme-challenge/ {
        return 404;
    }
}

```
