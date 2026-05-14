Получение ssl сертификатов на keenetic ported(форки без keendns)
Для получения сертификата обязательно наличие белого IP
если ip динамический, регистрируем его через любой сервис DynamicDNS
Для обновления сертификатов используется Nginx(его настройка не рассматривается в примере)

Для начала необходим высвободить порт 443 роутиера(он занят внутренними процессами
В моем примере пересаживаем его на 4433
/bin/ndmc -c "ip http ssl port 4433"
/bin/ndmc -c "system configuration save"



# устанавливаем пакеты uacme
opkg update
opkg install uacme uacme-ualpn
  
# регистриуем новаый аккаунт, готовим окружение
uacme -v -c /opt/etc/ssl/uacme new

# Важно 
# CHALLENGE_PATH - полный уть до каталога на внешнем порту 80 для обмена ключами
# Регистрируем один домем с подробным логированием
CHALLENGE_PATH="/opt/share/nginx/html/.well-known/acme-challenge" uacme -v -c /opt/etc/ssl/uacme -h /opt/share/uacme/uacme.sh issue anch665.my.to
# Регистрируем второй домем с подробным логированием
CHALLENGE_PATH="/opt/share/nginx/html/.well-known/acme-challenge" uacme -v -c /opt/etc/ssl/uacme -h /opt/share/uacme/uacme.sh issue anch665.root.sx
# регистрируем оба домена одним запросом с подробным логированием
CHALLENGE_PATH="/opt/share/nginx/html/.well-known/acme-challenge" uacme -v -c /opt/etc/ssl/uacme -h /opt/share/uacme/uacme.sh issue anch665.my.to anch665.root.sx

# При запуск с подробным логированим, будет видно(примеры):
# /opt/etc/ssl/uacme/private/anch665.my.to/key.pem - приватный ключ
# /opt/etc/ssl/uacme/anch665.my.to/cert.pem - сертификат 

# Сертификат выдается на 90 дней, в связи с этим ставим его в cron
