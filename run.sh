#!/usr/bin/env bash
set -euo pipefail

#Переменные для цветного вывода текста
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
BOLD=$(tput bold)  # Жирный
RESET=$(tput sgr0) # Отлючения стиля (если не делать - дальше в терминале будет использоваться)
EN_UNDERLINE=$(tput smul) # Вкл. подчеркивание
DIS_UNDERLINE=$(tput rmul) # Отк. подчеркивания

main() {
  VENV_PATH="${PWD}/.venv-ansible"
  mkdir -p _logs

  # Создаем venv если нет
  if [[ ! -d "$VENV_PATH" ]]; then
      echo "${GREEN}Создание виртуального окружения...${RESET}"
      virtualenv "$VENV_PATH" -p python3
  fi

  echo "${GREEN}Активация виртуального окружения...${RESET}"
  source "$VENV_PATH/bin/activate"

  # Установка зависимостей
  pip install --upgrade pip
  pip install -r ansible/requirements.txt
  ansible-galaxy collection install kubernetes.core community.hashi_vault

  export ANSIBLE_PYTHON_INTERPRETER="${VENV_PATH}/bin/python3"
  export VENV_PATH="${VENV_PATH}"

  # Экспорт переменных
  VARS_FILE="my_vars.yml"
  if [[ -f "$VARS_FILE" ]]; then
  #  source "$VARS_FILE"
    echo "${GREEN}Файл $VARS_FILE присутствует.${RESET}"
  else
    echo "${RED}Файл $VARS_FILE не найден.${RESET}"
    exit 1
  fi

  # Проверка пользователя
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "${YELLOW}Запуск осуществляется не от root, необходимо ввести пароль."
    read -s -p "Введите sudo пароль: ${RESET}" ANSIBLE_BECOME_PASS
    echo

    if [[ -z "$ANSIBLE_BECOME_PASS" ]]; then
      echo "${RED}Пароль не может быть пустым. Запустите скрипт заново.${RESET}"
      exit 1
    fi
      export ANSIBLE_BECOME_PASS=$ANSIBLE_BECOME_PASS
  else
    echo "${YELLOW}Запуск происходит от root - ANSIBLE_BECOME_PASS не требуется${RESET}"
  fi

  NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
  export NODE_IP=$NODE_IP
}

install() {
  LOG_FILE="_logs/$(date +"%Y%m%d_%H%M%S")_kuard_install.log"
  {
    cd ansible
    ansible-playbook -i inventory/hosts.ini playbooks/main.yml -e "@../$VARS_FILE"
  } 2>&1 | tee "$LOG_FILE"
  echo "${GREEN}УСтановка прошла успешно!${RESET}"
}

remove() {
  LOG_FILE="_logs/$(date +"%Y%m%d_%H%M%S")_kuard_remove.log"
  {
    cd ansible
    ansible-playbook -i inventory/hosts.ini playbooks/remove.yml -e "@../$VARS_FILE"
  } 2>&1 | tee "$LOG_FILE"
}

usage() {
  echo "${YELLOW}Usage:"
  echo
  echo "  ./run.sh [ OPTIONS ]"
  echo
  echo "Options:"
  echo
  echo "  -r, --remove             : Starting the kuard-installer removal."
  echo "  -h, --help               : Display this message ${RESET}"
}

case "${1:-}" in
    --remove|-r)
        main
        remove
        ;;
    --help|-h)
        usage
        ;;
    --*|-*)
        echo "Unknown flag: $1"
        usage
        ;;
    *)
        main
        install
        ;;
esac
