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
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

if [ -v CONDA_MODULE ]; then
  if [ -n "$CONDA_MODULE" ]; then
    conda install -y "$CONDA_MODULE"
  fi
fi
if [ -v PIP_MODULE ]; then
  if [ -n "$PIP_MODULE" ]; then
    for module in $PIP_MODULE; do
      pip install "$module"
    done
  fi
fi

if [ ! -e manage.py ]; then
  cd ../
  django-admin startproject "$DJANGO_NAME"
  mv "$DJANGO_NAME"/* html/
  cd html
fi

envs=(
  CRAWLER_NAME
  CRAWLER_MAIL
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

  set_config() {
    sed -ri -e "s/$1/$2/" /usr/src/settings.py
    sed -ri -e "s/$1/$2/" /usr/src/uwsgi.ini
  }

  set_config 'CRAWLER_NAME' "$CRAWLER_NAME"
  set_config 'CRAWLER_MAIL' "$CRAWLER_MAIL"
  set_config 'APP_NAME' "$DJANGO_NAME"
  set_config 'DB_HOST' "$DJANGO_DB_HOST"
  set_config 'DB_DATABASE' "$DJANGO_DB_NAME"
  set_config 'DB_USERNAME' "$DJANGO_DB_USER"
  set_config 'DB_PASSWORD' "$DJANGO_DB_PASSWORD"

  if [ -v INSTALLED_APPS ]; then
    if [ -n "$INSTALLED_APPS" ]; then
      for app in $INSTALLED_APPS; do
        sed -ri -e "/INSTALLED_APPS/,/MIDDLEWARE/ s/]/'$app',\n]/" /usr/src/settings.py
      done
    fi
  fi

  cp /usr/src/settings.py "$DJANGO_NAME/settings.py"
fi

for e in "${envs[@]}"; do
  unset "$e"
done

python manage.py collectstatic --noinput
uwsgi --ini /usr/src/uwsgi.ini
watcher.py -c /usr/src/watcher.ini start

python login.py
nohup python manage.py account > /dev/null 2>&1 &
nohup python manage.py tag > /dev/null 2>&1 &

exec "$@"
