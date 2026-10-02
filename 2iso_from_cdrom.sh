#!/bin/bash

ARGS_TEXT="Использование: cp_cdrom.sh [OPTIONS]...
скрипт по копирования с cdrom на указанное место

ВНИМАНИЕ: Для выполнения необходимы права пользователя root для записи в системные каталоги.

Аргументы:
    -o         Путь с названием файла на выходе (пример: /path1/path2/{filename} ).
    -l         Путь к cdrom
    -cp        Скопировать образ по стандартному пути - /tmp/isoroot/iso/{file.iso}? (y/n)

Аргументы (необязательные):
    -h, --help  Показать эту справку и выйти

Для вывода текущей справки используйте аргумент: --help"


C_RED="\033[91m"
C_GREEN="\033[92m"
C_YELLOW="\033[93m"
C_NONE="\033[0m"

ask=""
OUTPUT_FILE="astralinux"
DEVCD="/dev/sr0"

extension=".iso"
counter=1
filename=${OUTPUT_FILE}${extension}

while [[ -f "$OUTPUT_FILE" ]]; do
    filename="${OUTPUT_FILE}_${counter}"
    ((counter++))
done

while [ -n "$1" ]
do
    case "$1" in
        -o)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                OUTPUT_FILE="$2"
            else
                echo -e "${C_RED}Ошибка${C_NONE}: Не задано значение параметра $1"
                exit 1
            fi
            shift 2 ;;
        -cp)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                ask="$2"
            else
                echo -e "${C_RED}Ошибка${C_NONE}: Не задано значение параметра $1"
                exit 1
            fi
            shift 2 ;;
        -l)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                DEVCD="$2"
            else
                echo -e "${C_RED}Ошибка${C_NONE}: Не задано значение параметра $1"
                exit 1
            fi
            shift 2 ;;
        --help|-h)
            echo -e "$ARGS_TEXT"
            exit 0 ;;
        *)
            echo -e "${C_YELLOW}Неизвестный параметр: $1${C_NONE}"
            shift ;;
        --)
            shift ;;
    esac
done

function ask_cp() {
if [ -z "${ask}" ]; then
    while true; do
        read -p "Попробовать скопировать образ по стандартному пути - /tmp/isoroot/iso/$filename ? (y/n):" ask
        case $ask in
            [Yy]* ) echo -e "${C_YELLOW}Копируем...${C_NONE}"
                mv $filename /tmp/isoroot/iso/
                break;;
            [Nn]* ) echo -e "${C_YELLOW}Отмена копирования $PART3${C_NONE}"
                break;;
            * ) echo -e "${C_RED}Некорректный ответ, Введите y или n${C_NONE}"
                ;;
        esac
    done
elif [ "$ask" = "y" ]; then
    echo -e "${C_YELLOW}Копируем...${C_NONE}"
    mv $filename /tmp/isoroot/iso/
else
    echo -e "${C_YELLOW}Отмена копирования${C_NONE}"
fi
}

function cdrom_2_iso() {


while [[ -f "$filename" ]]; do
    filename="${OUTPUT_FILE}_${counter}${extension}"
    ((counter++))
done

dd if=$DEVCD of=$filename bs=4M status=progress
echo -e "${C_GREEN}Cоздан $filename${C_NONE}"

ask_cp

}

################
# Начало скрипта
################

cdrom_2_iso

