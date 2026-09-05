#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Инициализация проекта LAMP с Docker            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Проверяем, существует ли уже docker-compose.yml
SKIP_PHP_CHOICE=0
if [ -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}⚠ Файл docker-compose.yml уже существует!${NC}"
    read -p "Хотите перезаписать его? (y/N) [N]: " -r
    REPLY=${REPLY:-n}
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓ Используется существующий docker-compose.yml${NC}"
        SKIP_PHP_CHOICE=1
    fi
fi

if [ "$SKIP_PHP_CHOICE" -eq 0 ]; then
    # Выбор версии PHP
    echo -e "${GREEN}Выберите версию PHP:${NC}"
    echo "1) PHP 7.4"
    echo "2) PHP 8.0"
    echo "3) PHP 8.2"
    echo ""
    read -p "Введите номер (1-3) [1]: " php_choice
    php_choice=${php_choice:-1}

    case $php_choice in
        1)
            PHP_VERSION="php7.4"
            echo -e "${GREEN}✓ Выбрана версия PHP 7.4${NC}"
            ;;
        2)
            PHP_VERSION="php8.0"
            echo -e "${GREEN}✓ Выбрана версия PHP 8.0${NC}"
            ;;
        3)
            PHP_VERSION="php8.2"
            echo -e "${GREEN}✓ Выбрана версия PHP 8.2${NC}"
            ;;
        *)
            echo -e "${RED}✗ Неверный выбор! Используется PHP 7.4 по умолчанию${NC}"
            PHP_VERSION="php7.4"
            ;;
    esac

    echo ""
    echo -e "${BLUE}Копирование файлов конфигурации...${NC}"

    # Копируем docker-compose.yml
    if [ -f ".docker/templates/$PHP_VERSION/docker-compose.yml" ]; then
        cp ".docker/templates/$PHP_VERSION/docker-compose.yml" "docker-compose.yml"
        echo -e "${GREEN}✓ Скопирован docker-compose.yml для $PHP_VERSION${NC}"
    else
        echo -e "${RED}✗ Шаблон docker-compose.yml не найден для $PHP_VERSION${NC}"
        exit 1
    fi
fi

# Проверяем наличие .env файла
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo ""
        echo -e "${YELLOW}Файл .env не найден${NC}"
        read -p "Создать .env из .env.example? (Y/n) [Y]: " -r
        REPLY=${REPLY:-y}
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp ".env.example" ".env"
            echo -e "${GREEN}✓ Создан файл .env${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Файл .env.example не найден. Создайте .env вручную${NC}"
    fi
fi

if [ -f ".env" ]; then
    docker compose down 2>/dev/null || true
    docker compose build

    # Импорт базы данных
    echo ""
    read -p "Хотите импортировать SQL-файл из корня в базу данных сейчас? (y/N) [N]: " -r
    REPLY=${REPLY:-n}
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ./.docker/scripts/db_import.sh
    fi
else
    echo -e "${YELLOW}⚠ Пропуск сборки и импорта БД, так как файл .env отсутствует.${NC}"
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Инициализация завершена успешно!               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════╝${NC}"
echo ""
if [ -n "$PHP_VERSION" ]; then
    echo -e "${GREEN}Выбранная конфигурация: $PHP_VERSION${NC}"
else
    echo -e "${GREEN}Использована конфигурация из docker-compose.yml${NC}"
fi
