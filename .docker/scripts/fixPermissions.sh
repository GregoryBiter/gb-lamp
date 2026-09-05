#!/bin/bash

echo "Настройка прав доступа к файлам и папкам"
echo "$(pwd)"
sudo chown -R "$USER:$USER" .
sudo chmod -R 777 .