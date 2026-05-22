
## Telemt конфиг

Если белый динамичесикй IP регистрируем себе DynDNS, его будем использовать при конфигурировании, в моем примере mydomen.afraid.org

* https://freedns.afraid.org/menu/

```yaml
[general]
#fast_mode = true
use_middle_proxy = false
#use_middle_proxy = true

# Ограничения / валидация: "debug", "verbose", "normal", или "silent".
log_level = "silent"
upstream_connect_failfast_hard_errors = false
beobachten_file = "/tmp/cache/beobachten.txt"
ad_tag = "d3d7ceea02edf14cfbfe0f06639ed9b9"

[general.links]
public_host = "mydomen.afraid.org"
public_port = 443

[server]
port = 2443
metrics_port = 9090
#metrics_whitelist = ["127.0.0.1/32", "::1/128", "0.0.0.0/0"]
#metrics_whitelist = ["0.0.0.0/0"]
metrics_whitelist = ["192.168.0.0/19"]
metrics_listen = "192.168.1.1:9090"
# включить proxy_protocol для nginx
proxy_protocol = true

[server.api]
enabled = true
listen = "127.0.0.1:9091"
whitelist = [ "127.0.0.1/32", "::1/128" ]
minimal_runtime_enabled = true
minimal_runtime_cache_ttl_ms = 1000
read_only = false
auth_header = "31594ca6c3c6e109b14c13acec8a6f0116566312833625710cbd1042cad841c3"

[[server.listeners]]
ip = "127.0.0.1"

[censorship]
tls_domain = "mydomen.afraid.org"
mask = true
mask_port = 8443
mask_host = "127.0.0.1"
fake_cert_len = 2048
# включить mask_proxy_protocol для nginx
# 0 = выключен, 1 = v1 (текстовый), 2 = v2 (бинарный).
mask_proxy_protocol = 2

[access.users]

test = "739fd28dd22b6dafc45bbb2df1fbfd58"
[[upstreams]]
type = "direct"
# Указываем интерфейс который сомотрит в интернет здорового человека
interface = "nwg0"


[access.user_max_unique_ips]
test = 10

[access.user_max_tcp_conns]
test = 100
```

## Nginx
```nginx
user nobody;
worker_processes  1;

load_module /opt/lib/nginx/modules/ngx_stream_module.so;
events {
    worker_connections  64;
}

stream {
    log_format main  '$remote_addr [$time_iso8601] host=$ssl_preread_server_name prot=$protocol status=$status out=$bytes_sent in=$bytes_received';
    # mydomen.afraid.org -> 127.0.0.1:2443 (на :2443 MTProto proxy)
    map $ssl_preread_server_name $backend {
        mydomen.afraid.org 127.0.0.1:2443;
        default 127.0.0.1:8443 ;
    }
    server {
        listen 443;

        proxy_pass $backend;
        ssl_preread on;
        proxy_timeout 5m;
        proxy_connect_timeout 1s;
        proxy_protocol on;  # включаем прокси протокол, обязательно включить в конфиге telemt
        #access_log /opt/var/log/nginx/access_https.log proxy buffer=32k flush=5s;
    }
}

http {
    log_format main        '"$remote_addr" "$remote_user" "$time_iso8601" "$http_host" "$server_port" "$request" "$status" "$body_bytes_sent" "$request_time" "$http_user_agent"';
    log_format main_invite '$remote_addr - $time_iso8601 "$request"';

    # страница mydomen.afraid.org на :8443 - фоллбек из MTProto
    # для соединений без ключа
    server {
        # слушаем proxy_protocol
        listen 127.0.0.1:8443 ssl proxy_protocol;
        http2 on;
        server_name mydomen.afraid.org;

        # натсройки для пердачи реального IP через proxy_protocol
        set_real_ip_from 127.0.0.1;
        real_ip_header proxy_protocol;
        real_ip_recursive on;

        ssl_certificate /opt/etc/ssl/uacme/mydomen.afraid.org/cert.pem;
        ssl_certificate_key /opt/etc/ssl/uacme/private/mydomen.afraid.org/key.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers off;

        access_log /opt/var/log/nginx/access_https.log main buffer=32k flush=5s;

        root /opt/share/nginx/html;

        index index.html index.htm index.nginx-debian.html;

        location / {
            try_files $uri $uri/ =404;
        }

        # Закрываем доступ к .well-known по HTTPS (возвращаем 404)
        location ^~ /.well-known/acme-challenge/ {
            return 404;
        }
    }

    server {
        listen 81;
        server_name mydomen.afraid.org;

        #access_log /tmp/log/nginx/anch665-http.access.log main buffer=32k flush=5s;

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
}

```

