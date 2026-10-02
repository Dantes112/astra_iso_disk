#!/bin/bash

###
# скрипт по созданию hdd с legacy и efi загрузкой iso образов c запуском привелигерованно через hd-media
###


ARGS_TEXT="Использование: make-hd-astra-installer.sh [OPTIONS]...
скрипт по созданию hdd с legacy и efi загрузкой iso образов c запуском привелигерованно через hd-media

ВНИМАНИЕ: Для выполнения необходимы права пользователя root для записи в системные каталоги.

Аргументы:
    -p          Путь к grub.cfg.
    -d          Путь к диску на который будет производиться установка (пример: -d /dev/sdb).
    -i          Перечислите образы iso для копирования на установочный диск (пример: -i isofile1.iso | /path1/*.iso)
    -g          Укажите таблицу разделов (msdos/gpt)
    -u          Размонтировать установочный диск (y/n)
    -cr         Запуск скрипта по копированию файлов с cdrom (y/n)

    -crh        Вывод help от скрипта по копированию файлов с cdrom
    -pcr        Путь к скрипту копирования с cdrom

Аргументы (необязательные):
    -h, --help  Показать эту справку и выйти

Для вывода текущей справки используйте аргумент: --help"


C_RED="\033[91m"
C_GREEN="\033[92m"
C_YELLOW="\033[93m"
C_NONE="\033[0m"

GRUB_PATH="$PWD/grub.cfg"
CP_CDROM_PATH="$PWD/2iso_from_cdrom.sh"
DISK=""
COPY_ISO=""
DISK_PARTITION=""
CDROM_CP=""
CDROM_HELP="bash $CP_CDROM_PATH -h"
CDROM_FLAGS=""

while [ -n "$1" ]
do
    case "$1" in
        -p)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                GRUB_PATH="$2"
            else
                echo -e "${C_RED}Ошибка${C_NONE}: Не задано значение параметра $1"
                exit 1
            fi
            shift 2 ;;
        -d)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                DISK="$2"
            else
                echo -e "${C_RED}Ошибка${C_NONE}: Не задано значение параметра $1"
                exit 1
            fi
            shift 2 ;;
        -i)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                COPY_ISO="$2"
            else
                echo -e "${C_RED}Ошибка${C_NONE}: Не задано значение параметра $1"
                exit 1
            fi
            shift 2 ;;
        -g)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                DISK_PARTITION="$2"
            else
                echo -e "${C_RED}Ошибка${C_NONE}: Не задано значение параметра $1"
                exit 1
            fi
            shift 2 ;;
        -u)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                yn="$2"
            else
                echo -e "${C_RED}Ошибка${C_NONE}: Не задано значение параметра $1"
                exit 1
            fi
            shift 2 ;;
        -cr)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                CDROM_CP="$2"
            else
                echo -e "${C_RED}Ошибка${C_NONE}: Не задано значение параметра $1"
                exit 1
            fi
            shift 2 ;;
        -pcr)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                CP_CDROM_PATH="$2"
            else
                echo -e "${C_RED}Ошибка${C_NONE}: Не задано значение параметра $1"
                exit 1
            fi
            shift 2 ;;
        -crh)
            $CDROM_HELP
            exit 0;;

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

FLAGS=""

if [[ -n "${CDROM_FLAGS}" ]]; then
    FLAGS="$FLAGS -crf $CDROM_FLAGS"
fi

package=(
"gdisk"
"efibootmgr"
"grub-pc-bin"
"grub-pc"
"grub-efi-amd64-bin"
"grub-efi-amd64"
"grub-efi"
"gparted"
"debootstrap"
"console-setup"
"console-cyrillic"
)


# вывод текущихносителей
function check_lsblk() {
    lsblk | grep -e "part" -e "disk"
}

# установка memtest86+
function memtest() {
    if apt-cache show memtest86+ &>/dev/null || apt-cache policy memtest86+ | grep "Candidate:"; then
        echo -e "Установка memtest86+"
        mkdir -p $bootdir/memtest86+
        rm -fr memtest86+*.deb
        sudo apt download memtest86+
        sudo dpkg -x memtest86*.deb $bootdir/grub/memtest86+
        rm -fr memtest86+*.deb
    else
        echo -e "\\e[31m Пакет memtest86+ не найден для установки \\e[0m"
    fi
}

function make_gpt(){

    # Очистка всех разделов
    dd if=/dev/zero of="$DISK" bs=1M count=10

    # Определяем имена разделов
    case "$DISK" in
        /dev/nvme*)
            PART1="${DISK}p1"
            PART2="${DISK}p2"
            PART3="${DISK}p3"
            ;;
        *)
            PART1="${DISK}1"
            PART2="${DISK}2"
            PART3="${DISK}3"
            ;;
    esac

    # Создание MBR
    echo -e "${C_GREEN}Создание таблицы разделов${C_NONE}"
    parted -s "$DISK" mklabel gpt

    echo -e "${C_GREEN}Создание раздела boot${C_NONE}"
    parted -s "$DISK" mkpart primary 1MiB 10MiB set 1 bios_grub on name 1 "boot"

    echo -e "${C_GREEN}Создание раздела ESP${C_NONE}"
    parted -s "$DISK" mkpart primary 10MiB 1025MiB set 2 esp on name 2 "esp"
    sleep 1
    mkfs.vfat $PART2

    echo -e "${C_GREEN}Создание раздела data${C_NONE}"
    parted -s "$DISK" mkpart primary 1025MiB 100% name 3 "data"
    sleep 1
    mkfs.ext4 -F -q $PART3

    # Обновляем таблицу разделов
    partprobe "$DISK"

    # Каталоги монтирования
    mntp1=/tmp/efi
    mntp2=/tmp/root
    mntp3=/tmp/isoroot
    mntiso=/tmp/isoroot/iso
    bootdir=/tmp/root/boot
    efidir=/tmp/root/efi
    mntscripts=/tmp/isoroot/scripts

    # Монтируем разделы
    echo -e "${C_GREEN}Монтирование каталогов загрузчика и данных${C_NONE}"
    mkdir -p $mntp1
    mkdir -p $mntp2
    mkdir -p $mntp3

    sleep 1

    # Монтируем раздел boot
    echo -e "${C_GREEN}Монтируем раздел boot ($PART2 -> $mntp2)${C_NONE}"
    mount $PART2 $mntp2

    # Монтируем раздел data и создаём каталог для ISO-образов
    echo -e "${C_GREEN}Монтируем раздел data и создаём каталог для ISO-образов ($PART3 -> $mntp3)${C_NONE}"
    mount $PART3 $mntp3
    mkdir -p $mntiso
    mkdir -p $mntscripts
    cp $CP_CDROM_PATH $mntscripts
    chmod 777 $mntiso

    echo -e "${C_GREEN}Установка GRUB${C_NONE}"
    grub-install --target=i386-pc --boot-directory=$bootdir --recheck "$DISK"
    grub-install --target=x86_64-efi --efi-directory=$mntp2 --boot-directory=$bootdir --bootloader-id=GRUB --removable --recheck "$DISK"

    PATH_GRUB_CFG="${bootdir}/grub/grub.cfg"
    cp $GRUB_PATH $PATH_GRUB_CFG
    if grep -q "set root=(hd0,msdos3)" $PATH_GRUB_CFG; then
        sed -i 's/set root=(hd0,gpt3)/set root=(hd0,gpt3)/g' "$PATH_GRUB_CFG"
        echo -e "${C_YELLOW}В файле $PATH_GRUB_CFG заменили set root=(hd0,msdos3) на /set root=(hd0,gpt3)${C_NONE}"
    fi
}

function make_msdos() {

        # Очистка всех разделов
    dd if=/dev/zero of="$DISK" bs=1M count=10

    # Определяем имена разделов
    case "$DISK" in
        /dev/nvme*)
            PART1="${DISK}p1"
            PART2="${DISK}p2"
            PART3="${DISK}p3"
            ;;
        *)
            PART1="${DISK}1"
            PART2="${DISK}2"
            PART3="${DISK}3"
            ;;
    esac

    # Создание MBR
    echo -e "${C_GREEN}Создание таблицы разделов${C_NONE}"
    parted -s "$DISK" mklabel msdos

    echo -e "${C_GREEN}Создание разделов boot, esp, data${C_NONE}"

    echo -e "${C_GREEN} Создание раздела boot с флагами esp и boot${C_NONE}"
    parted -s "$DISK" mkpart primary 1MiB 1025MiB
    #parted -s "$DISK" set 1 boot on
    sleep 1
    mkfs.vfat $PART1

    echo -e "${C_GREEN} Создание раздела ESP${C_NONE}"
    parted -s "$DISK" mkpart primary 1025MiB 2025MiB
    parted -s "$DISK" set 2 esp on
    sleep 1
    mkfs.vfat $PART2

    echo -e "${C_GREEN} Создание раздела данных на всё оставшееся место${C_NONE}"
    parted -s "$DISK" mkpart primary 2025MiB 100%
    parted -s "$DISK" set 1 boot on
    sleep 1
    mkfs.ext4 -F -q $PART3

    echo -e "${C_GREEN} Обновляем таблицу разделов${C_NONE}"
    partprobe "$DISK"

    mntp1=/tmp/efi
    mntp2=/tmp/root
    mntp3=/tmp/isoroot
    mntiso=/tmp/isoroot/iso
    bootdir=/tmp/root/boot
    efidir=/tmp/root/efi
    mntscripts=/tmp/isoroot/scripts

    sleep 1

    echo -e "${C_GREEN} Монтируем разделы${C_NONE}"
    mkdir -p $mntp1
    mkdir -p $mntp2
    mkdir -p $mntp3
    mount $PART1 $mntp2
    mount $PART3 $mntp3
    mkdir -p $mntiso
    mkdir -p $mntscripts
    cp $CP_CDROM_PATH $mntscripts
    mount $PART2 $mntp1

    echo -e "${C_GREEN}Установка GRUB${C_NONE}"
    grub-install --target=i386-pc --boot-directory=$bootdir --recheck "$DISK"
    grub-install --target=x86_64-efi --efi-directory=$mntp1 --boot-directory=$bootdir --removable --recheck "$DISK"

    chmod 777 $mntiso

    PATH_GRUB_CFG="${bootdir}/grub/grub.cfg"
    cp $GRUB_PATH $PATH_GRUB_CFG
    if grep -q "set root=(hd0,gpt3)" $PATH_GRUB_CFG; then
        sed -i 's/set root=(hd0,gpt3)/set root=(hd0,msdos3)/g' "$PATH_GRUB_CFG"
        echo -e "${C_YELLOW}В файле $PATH_GRUB_CFG заменили set root=(hd0,gpt3) на /set root=(hd0,msdos3)${C_NONE}"
    fi
}

function ask_partition_dev() {

if [ -z "${DISK_PARTITION}" ]; then
    while true; do
        read -p "выберите таблицу разделов (msdos/gpt):" pt
        case $pt in
            [gpt]* ) echo -e "${C_YELLOW}разметка диска $DISK в GPT (gpt)${C_NONE}";
                make_gpt;
                break;;
            [msdos]* ) echo -e "${C_GREEN}разметка диска $DISK в MSDOS (msdos)${C_NONE}";
                make_msdos;
                break;;
            * ) echo -e "${C_RED}Некорректный ответ, Введите msdos или gpt${C_NONE}"
                ;;
        esac
    done
elif [ "$DISK_PARTITION" = "gpt" ]; then
    make_gpt;
else
    make_msdos;
fi
}

function umount_dev() {
    for mount_dev in `mount | grep $DISK | cut -d ' ' -f 1`; do
        umount $mount_dev
    done
}

function installing_packages() {
    # Установка пакетов
    for package in "${package[@]}"; do
        if dpkg -s "$package" &> /dev/null; then
            echo -e "\\e[32mПакет $package уже установлен\\e[0m"
        else
            echo -e "\\e[33mУстановка пакета $package\\e[0m"
            sudo apt update &> /dev/null
            sudo apt install -y "$package" &> /dev/null

            if dpkg -s "$package" &> /dev/null; then
                echo -e "\\e[32mПакет $package успешно установлен\\e[0m"
            else
                echo -e "\\e[31mОшибка установки пакета $package\\e[0m"
                sleep 5
            fi

        fi
    done
}

function ask_umount_dev() {
if [ -z "${yn}" ]; then
    while true; do
        read -p "Размонтировать все разделы установочного диска? (y/n):" yn
        case $yn in
            [Yy]* ) echo -e "${C_RED}Размонтируем...${C_NONE}"
                umount_dev
                break;;
            [Nn]* ) echo -e "${C_YELLOW}Не забудьте скопировать ISO файлы в $PART3${C_NONE}"
                break;;
            * ) echo -e "${C_RED}Некорректный ответ, Введите y или n${C_NONE}"
                ;;
        esac
    done
elif [ "$yn" = "y" ]; then
    echo -e "${C_RED}Размонтируем...${C_NONE}"
    umount_dev
else
    echo -e "${C_YELLOW}Не забудьте скопировать ISO файлы в $PART3${C_NONE}"
fi
}

function cp_iso() {
    if [ ! -z "${COPY_ISO}" ]; then
        echo -e "${C_YELLOW}Копирование выбранных готовых файлов ISO-образов...${C_NONE}"
        rsync -avh --progress $COPY_ISO $mntiso
    fi
}

function cdrom_script() {
bash $CP_CDROM_PATH -cp y
}


function ask_cdrom() {
if [ -z "${CDROM_CP}" ]; then
    while true; do
        read -p "Выполнить копирование файлов с cdrom? (y/n):" CDROM_CP
        case $CDROM_CP in
            [Yy]* ) echo -e "${C_YELLOW}Запускаем $CP_CDROM_PATH скрипт по копированию...${C_NONE}"
                cdrom_script
                break;;
            [Nn]* ) echo -e "${C_YELLOW} Скрипт $CP_CDROM_PATH проигнорирован ${C_NONE}"
                break;;
            * ) echo -e "${C_RED}Некорректный ответ, Введите y или n${C_NONE}"
                ;;
        esac
    done
elif [ "$CDROM_CP" = "y" ]; then
    echo -e "${C_RED} Запускаем $CP_CDROM_PATH скрипт по копированию... ${C_NONE}"
    cdrom_script
else
    echo -e "${C_YELLOW} Скрипт $CP_CDROM_PATH проигнорирован ${C_NONE}"
fi
}

function grub_script() {
    mkdir -p $bootdir/script

    SCRIPT_CFG_CONTENT='
    # вставьте сюда доп скрипты и подключите к grub.cfg'

    echo "$SCRIPT_CFG_CONTENT" | sudo tee $bootdir/script/autoiso.cfg > /dev/null
}

################
# Начало скрипта
################

echo -e "${C_YELLOW}Создание внешнего устройства установки/восстановления${C_NONE}"
sleep 1

echo -e "${C_YELLOW}Установка необходимых пакетов...
      Может занять некоторое время.${C_NONE}"

installing_packages
# Получение устройства (функция)
if [ -z "${DISK}" ]; then
    check_lsblk
    echo -e "${C_RED}Внимание все данные на выбранном диске будут удалены и размониторваны!${C_NONE}"
    read -p "Введите диск для установки (например /dev/sdX): " DISK
fi

# Проверка на наличие диска
DISK=$(readlink -f "$DISK")

BASENAME=$(basename "$DISK")
if [ ! -e "/sys/block/$BASENAME" ]; then
    echo -e "${C_RED}диск не найден${C_NONE}"
    echo "список доступных дисков:"
    check_lsblk
    exit 1
fi

# Демонтирование устройства
umount_dev

# Запрос типа таблицы разделов
ask_partition_dev

echo -e "${C_GREEN}Разметка и установка GRUB завершена${C_NONE}"
echo "Разделы:"
lsblk "$DISK"

#копирование iso
cp_iso

#копирование файлов с cdrom
ask_cdrom

#создание вспомогательного скрипта
grub_script

# Установка memtest
memtest

echo -e "${C_YELLOW}Демонтирование разделов устройства${C_NONE}"
ask_umount_dev
