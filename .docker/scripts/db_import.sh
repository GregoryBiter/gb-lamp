#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

ENV_FILE=".env"

# Проверяем, что .env существует
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Ошибка: файл $ENV_FILE не найден.${NC}"
    exit 1
fi

# Получаем настройки БД из .env
MYSQL_DATABASE=$(grep -E '^MYSQL_DATABASE=' "$ENV_FILE" | cut -d '=' -f2 | tr -d '\r')
MYSQL_ROOT_PASSWORD=$(grep -E '^MYSQL_ROOT_PASSWORD=' "$ENV_FILE" | cut -d '=' -f2 | tr -d '\r')

if [ -z "$MYSQL_DATABASE" ] || [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    echo -e "${RED}Ошибка: MYSQL_DATABASE или MYSQL_ROOT_PASSWORD не указаны в .env${NC}"
    exit 1
fi

# Поиск SQL файла в корне проекта
SQL_FILE=$(ls *.sql 2>/dev/null | head -n 1)

if [ -z "$SQL_FILE" ]; then
    echo -e "${YELLOW}Предупреждение: SQL файл не найден в корне проекта.${NC}"
    read -p "Введите путь к .sql файлу вручную: " SQL_FILE
    if [ ! -f "$SQL_FILE" ]; then
        echo -e "${RED}Ошибка: Файл $SQL_FILE не найден.${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}Импорт базы данных $SQL_FILE в контейнер db (база: $MYSQL_DATABASE)...${NC}"

# Проверяем, запущен ли контейнер db
if ! docker compose ps db | grep -q "running"; then
    echo -e "${YELLOW}Контейнер db не запущен. Запускаю...${NC}"
    docker compose up -d db
    echo -e "${BLUE}Ожидание запуска базы данных...${NC}"
    sleep 5
fi

# Очистка базы данных перед импортом
echo -e "${YELLOW}Проверка наличия таблиц в базе данных $MYSQL_DATABASE...${NC}"
TABLES=$(docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -e "SHOW TABLES;" | grep -v "Tables_in_")

if [ ! -z "$TABLES" ]; then
    echo -e "${YELLOW}База данных не пуста. Удаление всех таблиц...${NC}"
    # Отключаем проверку внешних ключей, чтобы успешно удалить все таблицы
    docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE" -e "SET FOREIGN_KEY_CHECKS = 0; SET @tables = NULL; SELECT GROUP_CONCAT('\`', table_name, '\`') INTO @tables FROM information_schema.tables WHERE table_schema = (SELECT DATABASE()); SET @tables = CONCAT('DROP TABLE IF EXISTS ', @tables); PREPARE stmt FROM @tables; EXECUTE stmt; DEALLOCATE PREPARE stmt; SET FOREIGN_KEY_CHECKS = 1;"
    echo -e "${GREEN}✓ База данных очищена.${NC}"
fi

# Выполняем импорт
cat "$SQL_FILE" | docker compose exec -T db mysql -u root -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ База данных успешно импортирована!${NC}"
else
    echo -e "${RED}✗ Произошла ошибка при импорте базы данных.${NC}"
    exit 1
fi
