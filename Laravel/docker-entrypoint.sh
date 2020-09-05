#!/bin/bash
set -euo pipefail

file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(<"${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
    if [ "$(id -u)" = '0' ]; then
        case "$1" in
        apache2*)
            user="${APACHE_RUN_USER:-www-data}"
            group="${APACHE_RUN_GROUP:-www-data}"

            # strip off any '#' symbol ('#1000' is valid syntax for Apache)
            pound='#'
            user="${user#$pound}"
            group="${group#$pound}"
            ;;
        *) # php-fpm
            user='www-data'
            group='www-data'
            ;;
        esac
    else
        user="$(id -u)"
        group="$(id -g)"
    fi

    if [ ! -e composer.json ]; then
        # if the directory exists and Laravel doesn't appear to be installed AND the permissions of it are root:root, let's chown it (likely a Docker-created directory)
        if [ "$(id -u)" = '0' ] && [ "$(stat -c '%u:%g' .)" = '0:0' ]; then
            chown "$user:$group" .
        fi

        echo >&2 "Laravel not found in $PWD - copying now..."
        if [ -n "$(ls -A)" ]; then
            echo >&2 "WARNING: $PWD is not empty! (copying anyhow)"
        fi
        sourceTarArgs=(
            --create
            --file -
            --directory /usr/src/laravel
            --owner "$user" --group "$group"
        )
        targetTarArgs=(
            --extract
            --file -
        )
        if [ "$user" != '0' ]; then
            # avoid "tar: .: Cannot utime: Operation not permitted" and "tar: .: Cannot change mode to rwxr-xr-x: Operation not permitted"
            targetTarArgs+=(--no-overwrite-dir)
        fi
        tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
        echo >&2 "Complete! Laravel has been successfully copied to $PWD"
    elif [ ! -d vendor ]; then
        echo >&2 "Vendor not found in $PWD - installing now..."
        composer install
    fi

    if [ ! -e .env ]; then
        cp .env.example .env
        chown "$user:$group" .env
    fi

    echo yes | php artisan key:gen

    if [ -v DO_MIGRATE ]; then
        if [ -n "$DO_MIGRATE" ]; then
            if [ "$DO_MIGRATE" != "false" ]; then
                echo yes | php artisan migrate
            fi
        fi
    fi

    # allow any of these "Authentication Unique Keys and Salts." to be specified via
    # environment variables with a "LARAVEL_" prefix (ie, "LARAVEL_AUTH_KEY")
    envs=(
        LARAVEL_NAME
        LARAVEL_ENV
        LARAVEL_DB_HOST
        LARAVEL_DB_USER
        LARAVEL_DB_PASSWORD
        LARAVEL_DB_NAME
    )
    haveConfig=
    for e in "${envs[@]}"; do
        file_env "$e"
        if [ -z "$haveConfig" ] && [ -n "${!e}" ]; then
            haveConfig=1
        fi
    done

    # linking backwards-compatibility
    if [ -n "${!MYSQL_ENV_MYSQL_*}" ]; then
        haveConfig=1
        # host defaults to "mysql" below if unspecified
        : "${LARAVEL_DB_USER:=${MYSQL_ENV_MYSQL_USER:-root}}"
        if [ "$LARAVEL_DB_USER" = 'root' ]; then
            : "${LARAVEL_DB_PASSWORD:=${MYSQL_ENV_MYSQL_ROOT_PASSWORD:-}}"
        else
            : "${LARAVEL_DB_PASSWORD:=${MYSQL_ENV_MYSQL_PASSWORD:-}}"
        fi
        : "${LARAVEL_DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-}}"
    fi

    # only touch ".env" if we have environment-supplied configuration values
    if [ "$haveConfig" ]; then
        : "${LARAVEL_NAME:=Laravel}"
        : "${LARAVEL_ENV:=local}"
        : "${LARAVEL_DB_HOST:=mysql}"
        : "${LARAVEL_DB_USER:=root}"
        : "${LARAVEL_DB_PASSWORD:=}"
        : "${LARAVEL_DB_NAME:=laravel}"

        set_config() {
            sed -ri -e "s/^$1.*/$1=$2/" .env
        }

        set_config 'APP_NAME' "$LARAVEL_NAME"
        set_config 'APP_ENV' "$LARAVEL_ENV"
        set_config 'DB_HOST' "$LARAVEL_DB_HOST"
        set_config 'DB_DATABASE' "$LARAVEL_DB_NAME"
        set_config 'DB_USERNAME' "$LARAVEL_DB_USER"
        set_config 'DB_PASSWORD' "$LARAVEL_DB_PASSWORD"
    fi

    # now that we're definitely done writing configuration, let's clear out the relevant envrionment variables (so that stray "phpinfo()" calls don't leak secrets from our code)
    for e in "${envs[@]}"; do
        unset "$e"
    done

    chown -R www-data:www-data .

    cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

    if [ -v DO_MIGRATION ]; then
        if [ "$DO_MIGRATION" ]; then
            php artisan migrate
        fi
    fi

    set_php() {
        sed -ri -e "s/.*$1.*/$1 = $2/" /usr/local/etc/php/php.ini
    }

    set_php 'memory_limit' '5G'
    set_php 'post_max_size' '5G'
    set_php 'upload_max_filesize' '5G'
fi

exec "$@"
