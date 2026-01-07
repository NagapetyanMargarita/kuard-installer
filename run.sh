#!/usr/bin/env bash
set -euo pipefail

# Экспорт переменных
VARS_FILE="my_vars.env"
if [[ -f "$VARS_FILE" ]]; then
  source "$VARS_FILE"
else
  echo "Файл $VARS_FILE не найден"
  exit 1
fi

# Проверка пользователя
if [[ "$(id -u)" -ne 0 ]]; then
  echo "Запуск осуществляется не от root, необходимо ввести пароль."
  read -s -p "Введите sudo пароль: " ANSIBLE_BECOME_PASS
  echo

  if [[ -z "$ANSIBLE_BECOME_PASS" ]]; then
    echo "Пароль не может быть пустым. Запустите скрипт заново."
    exit 1
  fi
  export ANSIBLE_BECOME_PASS
else
  echo "Запуск происходит от root — ANSIBLE_BECOME_PASS не требуется"
fi

mkdir -p logs
LOG_FILE="logs/$(date +"%Y%m%d_%H%M%S")_installer.log"
touch $LOG_FILE
# Запуск инсталлятора
{
  cd ansible
  ansible-playbook playbooks/main.yml
} 2>&1 | tee "$LOG_FILE"
