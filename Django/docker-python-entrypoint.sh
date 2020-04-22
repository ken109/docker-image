#!/bin/bash
set -meuo pipefail

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
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

if [ ! -e manage.py ]; then
  cd ../
  django-admin startproject "$DJANGO_NAME"
  mv "$DJANGO_NAME"/* django/
  cd django
fi

envs=(
  DJANGO_NAME
  DJANGO_DB_HOST
  DJANGO_DB_USER
  DJANGO_DB_PASSWORD
  DJANGO_DB_NAME
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
  if [ "$DJANGO_DB_USER" = 'root' ]; then
    : "${DJANGO_DB_PASSWORD:=${MYSQL_ENV_MYSQL_ROOT_PASSWORD:-}}"
  else
    : "${DJANGO_DB_PASSWORD:=${MYSQL_ENV_MYSQL_PASSWORD:-}}"
  fi
  : "${DJANGO_DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-}}"
fi

if [ "$haveConfig" ]; then
  : "${DJANGO_NAME:=Django}"
  : "${DJANGO_DB_HOST:=mysql}"
  : "${DJANGO_DB_USER:=root}"
  : "${DJANGO_DB_PASSWORD:=}"
  : "${DJANGO_DB_NAME:=django}"

  cp /usr/src/settings.py "$DJANGO_NAME/settings.py"

  set_config() {
    sed -ri -e "s/$1/$2/" "$DJANGO_NAME/settings.py"
    sed -ri -e "s/$1/$2/" /usr/src/unit.conf.json
  }

  set_config 'APP_NAME' "$DJANGO_NAME"
  set_config 'DB_HOST' "$DJANGO_DB_HOST"
  set_config 'DB_DATABASE' "$DJANGO_DB_NAME"
  set_config 'DB_USERNAME' "$DJANGO_DB_USER"
  set_config 'DB_PASSWORD' "$DJANGO_DB_PASSWORD"
fi

# now that we're definitely done writing configuration, let's clear out the relevant envrionment variables (so that stray "phpinfo()" calls don't leak secrets from our code)
for e in "${envs[@]}"; do
  unset "$e"
done

python manage.py collectstatic --noinput

unitd --no-daemon --control unix:/var/run/control.unit.sock &
curl -X PUT -d@/usr/src/unit.conf.json --unix-socket /var/run/control.unit.sock http://localhost/config/
fg 1
