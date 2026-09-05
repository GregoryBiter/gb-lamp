#!/bin/bash

# ==============================================================================
# GB-LAMP Installer
# Установка и настройка Docker-окружения LAMP в текущий проект
# Репозиторий: https://github.com/GregoryBiter/gb-lamp
# Запуск: curl -sSL https://raw.githubusercontent.com/GregoryBiter/gb-lamp/main/lamp.sh | bash
# ==============================================================================

set -e

# Цвета для терминала
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

REPO_TAR_URL="https://github.com/GregoryBiter/gb-lamp/archive/refs/heads/main.tar.gz"
PROJECT_DIR="$(pwd)"
DEFAULT_DOMAIN="$(basename "$PROJECT_DIR").local"

# Проверка флагов неинтерактивного запуска
AUTO_ACCEPT=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes|--non-interactive|-d|--default)
            AUTO_ACCEPT=1
            ;;
    esac
done

# Проверка наличия интерактивного терминала
INTERACTIVE=0
if [ "$AUTO_ACCEPT" -eq 0 ] && [ "${NON_INTERACTIVE:-0}" != "1" ]; then
    if [ -t 0 ]; then
        INTERACTIVE=1
    elif [ -t 1 ] && [ -r /dev/tty ]; then
        # stdin передается через пайп (curl ... | bash), но stdout подключен к терминалу
        INTERACTIVE=2
    fi
fi

# Функции безопасного чтения ввода
read_input() {
    local prompt="$1"
    local var_name="$2"
    local default_val="$3"
    local val=""

    if [ "$INTERACTIVE" -eq 1 ]; then
        read -p "$prompt" val
    elif [ "$INTERACTIVE" -eq 2 ]; then
        read -p "$prompt" val < /dev/tty
    else
        val="$default_val"
        echo "${prompt}${default_val} (авто)"
    fi

    if [ -z "$val" ]; then
        val="$default_val"
    fi
    eval "$var_name=\"$val\""
}

read_yn() {
    local prompt="$1"
    local var_name="$2"
    local default_val="$3"
    local val=""

    if [ "$INTERACTIVE" -eq 1 ]; then
        read -n 1 -r -p "$prompt" val
        echo ""
    elif [ "$INTERACTIVE" -eq 2 ]; then
        read -n 1 -r -p "$prompt" val < /dev/tty
        echo ""
    else
        val="$default_val"
        echo "${prompt}${default_val} (авто)"
    fi

    if [ -z "$val" ]; then
        val="$default_val"
    fi
    eval "$var_name=\"$val\""
}

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║          GB-LAMP: Установка Docker в проект              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo -e "Целевой каталог: ${GREEN}$PROJECT_DIR${NC}"
echo ""

# Шаг 1: Получение файлов окружения (локально или из GitHub)
TMP_DIR=""
cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

# Источник файлов GB-LAMP: переменная GB_LAMP_SRC, текущая папка или GitHub
if [ -n "${GB_LAMP_SRC:-}" ] && [ -d "$GB_LAMP_SRC/.docker" ]; then
    echo -e "${GREEN}✓ Использование файлов GB-LAMP из $GB_LAMP_SRC${NC}"
    SRC_DIR="$GB_LAMP_SRC"
elif [ -d ".docker/templates" ] && [ -f ".env.example" ]; then
    echo -e "${GREEN}✓ Использование локальных файлов GB-LAMP${NC}"
    SRC_DIR="$PROJECT_DIR"
else
    echo -e "${BLUE}Загрузка компонентов GB-LAMP из GitHub...${NC}"
    TMP_DIR=$(mktemp -d)
    if command -v curl >/dev/null 2>&1; then
        curl -sSL "$REPO_TAR_URL" | tar -xz -C "$TMP_DIR"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$REPO_TAR_URL" | tar -xz -C "$TMP_DIR"
    else
        echo -e "${RED}Ошибка: curl или wget не найдены. Установите curl или wget.${NC}"
        exit 1
    fi
    SRC_DIR="$TMP_DIR/gb-lamp-main"
    echo -e "${GREEN}✓ Компоненты успешно загружены${NC}"
fi

echo ""

# Шаг 2: Копирование .docker/ и служебных файлов
echo -e "${BLUE}Копирование служебных файлов окружения...${NC}"

# Копируем .docker/
if [ "$SRC_DIR" != "$PROJECT_DIR" ]; then
    cp -r "$SRC_DIR/.docker" "$PROJECT_DIR/"
fi

# Копируем run.sh
if [ "$SRC_DIR" != "$PROJECT_DIR" ] || [ ! -f "run.sh" ]; then
    cp "$SRC_DIR/run.sh" "$PROJECT_DIR/run.sh"
    chmod +x "$PROJECT_DIR/run.sh"
fi

# Копируем .env.example
if [ ! -f ".env.example" ]; then
    cp "$SRC_DIR/.env.example" "$PROJECT_DIR/.env.example"
fi

# Копируем .vscode если его нет
if [ ! -d ".vscode" ] && [ -d "$SRC_DIR/.vscode" ]; then
    cp -r "$SRC_DIR/.vscode" "$PROJECT_DIR/.vscode"
    echo -e "${GREEN}✓ Добавлена конфигурация отладки .vscode${NC}"
fi

# Обработка Makefile
if [ ! -f "Makefile" ]; then
    cp "$SRC_DIR/Makefile" "$PROJECT_DIR/Makefile"
    echo -e "${GREEN}✓ Создан Makefile${NC}"
else
    # Проверяем, есть ли уже команды LAMP в существующем Makefile
    if ! grep -q "start:" "Makefile"; then
        echo "" >> Makefile
        echo "# === GB-LAMP Commands ===" >> Makefile
        echo ".PHONY: init start clean db-import fix-permissions" >> Makefile
        echo "init: ## Инициализировать проект с выбором версии PHP" >> Makefile
        echo -e "\t./.docker/scripts/init.sh" >> Makefile
        echo "start: ## Запустить проект" >> Makefile
        echo -e "\t./.docker/scripts/start.sh" >> Makefile
        echo "db-import: ## Импортировать SQL-файл" >> Makefile
        echo -e "\t./.docker/scripts/db_import.sh" >> Makefile
        echo "clean: ## Очистить контейнеры и образы" >> Makefile
        echo -e "\tdocker compose down --volumes --remove-orphans" >> Makefile
        echo -e "\tdocker system prune -f" >> Makefile
        echo "fix-permissions: ## Настроить права доступа к файлам и папкам проекта" >> Makefile
        echo -e "\t./.docker/scripts/fixPermissions.sh" >> Makefile
        echo -e "${GREEN}✓ Цели GB-LAMP добавлены в существующий Makefile${NC}"
    fi
fi

echo -e "${GREEN}✓ Файлы окружения скопированы${NC}"
echo ""

# Шаг 3: Выбор версии PHP
echo -e "${GREEN}Выберите версию PHP для проекта:${NC}"
echo "1) PHP 7.4 (по умолчанию)"
echo "2) PHP 8.0"
echo "3) PHP 8.2"
read_input "Введите номер (1-3) [1]: " php_choice "1"

case $php_choice in
    1)
        PHP_VERSION="php7.4"
        ;;
    2)
        PHP_VERSION="php8.0"
        ;;
    3)
        PHP_VERSION="php8.2"
        ;;
    *)
        PHP_VERSION="php7.4"
        ;;
esac

echo -e "${GREEN}✓ Выбрана версия $PHP_VERSION${NC}"
cp ".docker/templates/$PHP_VERSION/docker-compose.yml" "docker-compose.yml"
echo -e "${GREEN}✓ Создан docker-compose.yml ($PHP_VERSION)${NC}"
echo ""

# Шаг 4: Настройка .env и домена
read_input "Введите имя локального домена [$DEFAULT_DOMAIN]: " vhost_name "$DEFAULT_DOMAIN"

if [ ! -f ".env" ]; then
    cp ".env.example" ".env"
fi

# Обновляем VHOST_SERVER_NAME в .env
if grep -q "^VHOST_SERVER_NAME=" ".env"; then
    sed -i "s/^VHOST_SERVER_NAME=.*/VHOST_SERVER_NAME=$vhost_name/" ".env"
else
    echo "VHOST_SERVER_NAME=$vhost_name" >> ".env"
fi

echo -e "${GREEN}✓ Настроен файл .env (домен: $vhost_name)${NC}"
echo ""

# Шаг 5: Обновление .gitignore
if [ ! -f ".gitignore" ]; then
    touch ".gitignore"
fi

if ! grep -q "GB-LAMP Environment" ".gitignore"; then
    cat << 'EOF' >> .gitignore

# === GB-LAMP Environment ===
/.docker/logs/apache2/*
/.docker/logs/php/*
docker-compose.yml
.tmpDocker/
.env
*.sql

# === OpenCart Cache & Logs ===
/system/storage/cache/*
!/system/storage/cache/index.html
/system/storage/logs/*
!/system/storage/logs/index.html
/system/storage/session/*
!/system/storage/session/index.html
/system/storage/modification/*
!/system/storage/modification/index.html
/image/cache/*
!/image/cache/index.html
EOF
    echo -e "${GREEN}✓ Секции GB-LAMP и OpenCart добавлены в .gitignore${NC}"
fi

# Шаг 6: Проверка OpenCart
if [ -d "catalog" ] || [ -d "admin" ]; then
    echo ""
    echo -e "${YELLOW}Обнаружена структура каталогов OpenCart.${NC}"
    read_yn "Скопировать базовые файлы конфигурации (config.php, admin/config.php, .htaccess) из примера? (y/n) [n]: " copy_oc "n"
    if [[ $copy_oc =~ ^[Yy]$ ]]; then
        OC_SOURCE=".docker/example-config/opencart-3"
        for f in "config.php" "admin/config.php" ".htaccess"; do
            mkdir -p "$(dirname "$f")"
            if [ -f "$f" ]; then
                read_yn "Файл $f уже существует. Перезаписать? (y/n) [n]: " overwrite "n"
                if [[ $overwrite =~ ^[Yy]$ ]]; then
                    cp "$OC_SOURCE/$f" "$f"
                    echo -e "${GREEN}✓ Перезаписан $f${NC}"
                fi
            else
                cp "$OC_SOURCE/$f" "$f"
                echo -e "${GREEN}✓ Скопирован $f${NC}"
            fi
        done
    fi
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║            Установка успешно завершена!                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Домен проекта:   ${GREEN}http://$vhost_name${NC}"
echo -e "Панель phpMyAdmin: ${GREEN}http://localhost:8080${NC}"
echo ""

# Шаг 7: Предложение запустить проект прямо сейчас
default_run="y"
if [ "$INTERACTIVE" -eq 0 ]; then
    default_run="n"
fi
read_yn "Запустить Docker-контейнеры сейчас? (y/n) [$default_run]: " run_now "$default_run"
if [[ $run_now =~ ^[Yy]$ ]]; then
    ./.docker/scripts/start.sh
else
    echo -e "${YELLOW}Для последующего запуска выполните:${NC} make start (или ./run.sh)"
fi
