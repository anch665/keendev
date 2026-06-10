
Включаем принудительную синхронизацию времени раз в час
```bash
ndmc -c ntp server 0.ru.pool.ntp.org
ndmc -c ntp server 1.ru.pool.ntp.org
ndmc -c ntp server 3.ru.pool.ntp.org
ndmc -c ntp server ntp.ix.ru
ndmc -c ntp sync-period 60
ndmc -c system configuration save
```

проверка синхронизации
```bash
ndmc -c "show log" | grep 'Ntp::Client'
```
