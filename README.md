# Pet VPN

Личный VPN-сервер на базе **AmneziaWG** (обфусцированный WireGuard-форк) с маскировкой SSH через **GOST**. Управляется полностью через Ansible.

## Архитектура

```
Клиент (Mac/Android/iOS/Windows/Linux)
        │  AmneziaWG (обфусцированный протокол)
        ▼
   Amsterdam VPS (Debian 13)
        │  NAT / IP forwarding
        ▼
     Интернет
```

- **1 VPS** (FirstVDS, Amsterdam, Debian 13.5, x86_64)
- **AmneziaWG** — основной VPN-транспорт (собственный туннель на порту 443/udp)
- **GOST** — маскировка SSH-доступа под HTTPS (WSS → SOCKS5 → 127.0.0.1:22), не связан с VPN-трафиком
- Архитектура рассчитана на расширение: второй VPS, дополнительные транспорты (XRay VLESS Reality) без переделки базы

## Структура репозитория

```
inventory.yml           # хосты Ansible (не в git, содержит IP/пути к ключам)
inventory_base.yml       # шаблон inventory без секретов
ansible.cfg              # конфигурация Ansible (не в git)
playbooks/vpn.yml        # главный playbook
playbooks/users.yml      # создание nonroot пользователей
ssh_keys/                # публичные SSH-ключи пользователей (<имя>.pub), в git
roles/
  base/                  # базовые пакеты (curl, tcpdump, gcc, git и т.д.)
  users/                 # nonroot пользователи и их SSH-ключи
  gost/                  # маскировка SSH под HTTPS
  amneziawg_go/          # вся логика AmneziaWG: сборка, systemd, ключи, конфиги клиентов
configs/                 # клиентские .conf файлы (не в git — приватные ключи)
```

## Роль `amneziawg_go`

Задачи выполняются последовательно (`tasks/main.yml`):

1. **golang.yml** — установка тулчейна Go (версия и checksum зафиксированы)
2. **build.yml** — сборка `amneziawg-go` из исходников (пиннинг тега, без `latest`)
3. **configure.yml** — systemd unit `amneziawg-go.service` (foreground, `Restart=always`)
4. **tools.yml** — сборка `amneziawg-tools` (`awg`/`awg-quick`), версия подобрана под совместимость с `amneziawg-go`
5. **network.yml** — `ip_forward`, NAT (masquerade) через ufw
6. **secrets.yml** — генерация ключей **на самой VPS** (приватные ключи никогда не покидают сервер и не попадают в git/на Mac)
7. **interface.yml** — рендер конфигурации интерфейса `wg0` и клиентских `.conf` файлов

## Пользователи

Роль `users` создаёт пользователей по файлам в `ssh_keys/`: файл `ssh_keys/<имя>.pub` даёт пользователя `<имя>` с этим ключом в `authorized_keys` (ключей в файле может быть несколько, лишние на сервере удаляются). Пароль заблокирован, вход только по ключу. При `users_sudo: true` пользователь получает sudo без пароля (`/etc/sudoers.d/90-<имя>`). Публичные ключи не секрет и лежат в git, приватные остаются у владельцев.

## Клиенты

Список задаётся в `playbooks/vpn.yml` (`amneziawg_clients`), адреса назначаются по порядку в списке. Чтобы добавить устройство — дописать имя **в конец** списка и прогнать playbook.

Клиентские конфиги нужно импортировать в **нативный AmneziaWG-клиент** (обычный WireGuard-клиент их не поймёт — упадёт на полях Jc/S1/...):

| Платформа             | Клиент                                          |
|-----------------------|-------------------------------------------------|
| Android               | Play Store: `org.amnezia.awg`                   |
| iOS / macOS           | App Store: AmneziaWG                            |
| Windows               | github.com/amnezia-vpn/amneziawg-windows-client |
| Linux                 | пакет `amneziawg-tools`, `awg-quick up <имя>`   |
| Android TV / Smart TV | сайдлоуд APK                                    |

Забрать готовый конфиг с сервера:

## Использование

```bash
# Прогон только одной роли
ansible-playbook -i inventory.yml playbooks/vpn.yml --tags amneziawg

# Создание пользователей из ssh_keys/
ansible-playbook -i inventory.yml playbooks/users.yml
```

`ansible.cfg` не хранится в git — inventory путь передаётся явно через `-i inventory.yml`.

## Безопасность

- Приватные ключи и клиентские конфиги — только на VPS, в git не коммитятся (`.gitignore`)
- SSH-доступ по ключу, не отключается ни при каких изменениях firewall
- `ufw` настроен с сохранением существующих правил (SSH, старые порты)
