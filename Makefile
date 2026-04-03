.PHONY: help init start clean db-import

help: ## Показать эту справку
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Инициализировать проект с выбором версии PHP (7.4, 8.0, 8.2)
	./.docker/scripts/init.sh

start: ## Запустить проект (проверить .env, скопировать конфиги, добавить хост, запустить Docker)
	./.docker/scripts/start.sh

db-import: ## Импортировать SQL-файл из корня в базу данных MariaDB
	./.docker/scripts/db_import.sh

clean: ## Очистить контейнеры и образы
	docker compose down --volumes --remove-orphans
	docker system prune -f