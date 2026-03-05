#!/bin/bash

set -e  # Зупинити виконання при помилці

ENV_FILE=".env"
HOSTS_FILE="/etc/hosts"
IP="127.0.0.1"
SOURCE_DIR=".docker/example-config/opencart-3"
DEST_DIR="www"
CONFIG_FILES=("config.php" "admin/config.php" ".htaccess")

# Функция для копирования конфигурационных файлов
copy_configs() {
    for file in "${CONFIG_FILES[@]}"; do
        src="$SOURCE_DIR/$file"
        dest="$DEST_DIR/$file"
        if [ -f "$dest" ]; then
            if cmp -s "$src" "$dest"; then
                echo "$file уже скопирован и совпадает."
            else
                echo "$file существует и отличается."
                read -p "Перезаписать? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    cp "$src" "$dest"
                    echo "✓ Перезаписан $file"
                fi
            fi
        else
            cp "$src" "$dest"
            echo "✓ Скопирован $file"
        fi
    done
}

# Перевіряємо, що .env існує
if [ ! -f "$ENV_FILE" ]; then
  echo "Помилка: файл $ENV_FILE не знайдено."
  exit 1
fi

# Отримуємо VHOST_SERVER_NAME з .env
VHOST_SERVER_NAME=$(grep -E '^VHOST_SERVER_NAME=' "$ENV_FILE" | cut -d '=' -f2 | tr -d '\r')

if [ -z "$VHOST_SERVER_NAME" ]; then
  echo "Помилка: VHOST_SERVER_NAME не вказано в .env"
  exit 1
fi

# Спрашиваем о копировании конфигурационных файлов
read -p "Хотите скопировать файлы конфигурации (config.php, admin/config.php, .htaccess) из примера в папку www? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    copy_configs
fi

# Перевіряємо, чи запис вже є
if grep -qE "\s$VHOST_SERVER_NAME(\s|\$)" "$HOSTS_FILE"; then
  echo "$VHOST_SERVER_NAME вже є у $HOSTS_FILE"
else
  echo "Додаємо $VHOST_SERVER_NAME → $IP у $HOSTS_FILE"
  echo "$IP $VHOST_SERVER_NAME" | sudo tee -a "$HOSTS_FILE" > /dev/null
  echo "✅ Додано: $IP $VHOST_SERVER_NAME"
fi

# Останавливаем все запущенные контейнеры
echo "🛑 Останавливаем все запущенные контейнеры..."
docker stop $(docker ps -q) 2>/dev/null || echo "Немає запущених контейнерів"

# Запускаємо Docker Compose
echo "🚀 Запускаємо docker compose..."
docker compose up -d
