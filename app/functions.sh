#!/usr/bin/env bash
set -o nounset
set -o errexit
set -o pipefail

declare no_symlinks='on'

# Linux/Mac abstraction
function get_realpath(){
    [[ ! -f "$1" ]] && return 1 # failure : file does not exist.
    [[ -n "$no_symlinks" ]] && local pwdp='pwd -P' || local pwdp='pwd' # do symlinks.
    echo "$( cd "$( echo "${1%/*}" )" 2>/dev/null; $pwdp )"/"${1##*/}" # echo result.
    return 0
}

# Set magic variables for current FILE & DIR
declare -r __FILE__=$(get_realpath ${BASH_SOURCE[0]})
declare -r __DIR__=$(dirname $__FILE__)

# Coloring/Styling helpers
esc=$(printf '\033')
reset="${esc}[0m"
blue="${esc}[34m"
green="${esc}[32m"
red="${esc}[31m"
bold="${esc}[1m"
warn="${esc}[41m${esc}[97m"

function printError(){
    >&2 echo -e "$@"
}

function promptYesOrNo(){
    declare prompt="$1"
    declare default=${2:-""}

    while true
        do
            read -p "$prompt" answer
                case $(echo "$answer" | `which awk` '{print tolower($0)}') in
                    y|yes)
                        echo 'y'
                        break
                        ;;
                    n|no)
                        echo 'n'
                        break
                        ;;
                    *)
                        if [ -z "$answer" ] && [ ! -z "$default" ] ; then
                            echo "$default"
                            break
                        fi
                        printError "Please enter y or n!"
                        ;;
        esac
    done
}

function swCommand(){
    ${__DIR__}/../bin/console "$@"
}

function banner(){
    echo -n "${blue}"
    cat ${__DIR__}/banner.txt
    echo "${reset}"
}

function envFileDoesNotExists(){
    [ ! -f ${__DIR__}/../.env ]
    return $?
}

function createEnvFile(){

    echo -e "\n--------------------------"
    echo -e "Database settings"
    echo -e "--------------------------\n"

    read -p "Enter your database host (default: 127.0.0.1): " MYSQL_HOST
    MYSQL_HOST=${MYSQL_HOST:-"127.0.0.1"}

    read -p "Enter your database name (default: swcomposer): " MYSQL_DATABASE
    MYSQL_DATABASE=${MYSQL_DATABASE:-swcomposer}

    read -p "Enter your database username (default: shopware): " MYSQL_USER
    MYSQL_USER=${MYSQL_USER:-shopware}

    read -p "Enter your database password (default: shopware): " MYSQL_PASSWORD
    MYSQL_PASSWORD=${MYSQL_PASSWORD:-shopware}
    MYSQL_PASSWORD=${MYSQL_PASSWORD//\"/\\\"} # Escapes apostrophes

    read -p "Enter your database port number (default: 3306): " MYSQL_PORT
    MYSQL_PORT=${MYSQL_PORT:-"3306"}

    echo -e "\n--------------------------"
    echo -e "Admin settings"
    echo -e "--------------------------\n"

    read -p "Admin username (default: demo): " ADMIN_USERNAME
    ADMIN_USERNAME=${ADMIN_USERNAME:-demo}

    read -p "Admin password (default: demo): " ADMIN_PASSWORD
    ADMIN_PASSWORD=${ADMIN_PASSWORD:-demo}

    read -p "Admin name (default: John Doe): " ADMIN_NAME
    ADMIN_NAME=${ADMIN_NAME:-"John Doe"}

    read -p "Admin email (default: demo@demo.com): " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-"demo@demo.com"}

    echo -e "\n--------------------------"
    echo -e "Shop settings"
    echo -e "--------------------------\n"

    read -p "Enter your shop URL incl. protocol and path (default: http://shopware.example/path): " SHOP_URL
    SHOP_URL=${SHOP_URL:-http://shopware.example/path}

    IMPORT_DEMODATA=$(promptYesOrNo "Would you like to install demo data? (Y/n) " 'y')

    echo -e "# This file was generated by the shopware composer shell installer\n" > ${__DIR__}/../.env
    echo -e "# Shop environment and database connection" >> ${__DIR__}/../.env
    echo -e "SHOPWARE_ENV=\"dev\"" >> ${__DIR__}/../.env

    echo -e "\n# The URL has priority over the other values, so only one parameter needs to be set in production environments" >> ${__DIR__}/../.env
    echo -e "DATABASE_URL=\"mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}\"\n" >> ${__DIR__}/../.env

    echo -e "# If e.g. the password contains special chars not allowed in a URL, you can define each parameter by itself instead" >> ${__DIR__}/../.env
    echo -e "MYSQL_HOST=\"${MYSQL_HOST}\"" >> ${__DIR__}/../.env
    echo -e "MYSQL_DATABASE=\"${MYSQL_DATABASE}\"" >> ${__DIR__}/../.env
    echo -e "MYSQL_USER=\"${MYSQL_USER}\"" >> ${__DIR__}/../.env
    echo -e "MYSQL_PASSWORD=\"${MYSQL_PASSWORD}\"" >> ${__DIR__}/../.env
    echo -e "MYSQL_PORT=\"${MYSQL_PORT}\"" >> ${__DIR__}/../.env

    echo -e "\n# Installation configuration (can be removed after installation)" >> ${__DIR__}/../.env
    echo -e "ADMIN_EMAIL=\"$ADMIN_EMAIL\"" >> ${__DIR__}/../.env
    echo -e "ADMIN_NAME=\"$ADMIN_NAME\"" >> ${__DIR__}/../.env
    echo -e "ADMIN_USERNAME=\"$ADMIN_USERNAME\"" >> ${__DIR__}/../.env
    echo -e "ADMIN_PASSWORD=\"$ADMIN_PASSWORD\"" >> ${__DIR__}/../.env
    echo -e "SHOP_URL=\"$SHOP_URL\"\n" >>  ${__DIR__}/../.env
    echo -e "IMPORT_DEMODATA=$IMPORT_DEMODATA" >> ${__DIR__}/../.env
}

function loadEnvFile(){
    if [ -f $__DIR__/../.env ]; then
        echo "${green}Loading configuration settings from .env file${reset}"
        source $__DIR__/../.env
        return
    fi
    echo "Could not load .env file"
    exit 1
}

function createEnvFileInteractive(){
    declare correct=0;

    while [[ ${correct} != 'y' ]]
        do
            createEnvFile
            echo -e "\n----------------------------------------------------------"
            echo -e "The following settings have been written to the .env file:"
            echo -e "----------------------------------------------------------\n"
            cat ${__DIR__}/../.env
            echo -e "----------------------------------------------------------------\n"
            correct=$(promptYesOrNo "Is this information correct? (Y/n) " 'y')
    done
}

function createSymLinks(){
    echo "Creating symlinks in $__DIR__"
    cd $__DIR__/..
    rm -rf  engine/Library
    mkdir -p engine/Library
    ln -s ../../vendor/shopware/shopware/engine/Library/CodeMirror engine/Library/CodeMirror
    ln -s ../../vendor/shopware/shopware/engine/Library/ExtJs engine/Library/ExtJs
    ln -s ../../vendor/shopware/shopware/engine/Library/TinyMce engine/Library/TinyMce
    
    rm -rf tests
    ln -s vendor/shopware/shopware/tests tests

    rm -rf themes/Frontend/{Bare,Responsive}
    rm -rf themes/Backend/ExtJs

    mkdir -p themes/{Frontend,Backend}

    ln -s ../../vendor/shopware/shopware/themes/Backend/ExtJs themes/Backend/ExtJs
    ln -s ../../vendor/shopware/shopware/themes/Frontend/Bare themes/Frontend/Bare
    ln -s ../../vendor/shopware/shopware/themes/Frontend/Responsive themes/Frontend/Responsive
}

