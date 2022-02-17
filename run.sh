#!/bin/bash
# Credits for: Krzysieqq (https://github.com/krzysieqq/DGNP)
set -e

# Setup Main Container for Project
MAIN_CONTAINER=backend
PROJECT_NAME=
#ADDITIONAL_DOCKER_COMPOSE_PARAMS="-f ./docker/docker-compose.local.yml"
LOCAL_FILES="
./docker/docker-compose.local.yml.example
./docker/entrypoint.local.sh.example
./docker/requirements.local.txt.example
./envs/.env.local.example"


function compose() {
  CI_REGISTRY=localhost RELEASE_VERSION=local docker-compose -f ./docker/docker-compose.yml $ADDITIONAL_DOCKER_COMPOSE_PARAMS -p $PROJECT_NAME $@
}

function setup_local_project() {
  sed -i '1,/PROJECT_NAME=/{x;/first/s///;x;s/PROJECT_NAME=/PROJECT_NAME='$1'/;}' ./run.sh
  sed -i '1,/PROJECT_NAME=/{x;/first/s///;x;s/PROJECT_NAME=/PROJECT_NAME='$1'/;}' ./envs/.env.local.example
  sed -i '1,/DJANGO_SETTINGS_MODULE=/{x;/first/s///;x;s/DJANGO_SETTINGS_MODULE=/DJANGO_SETTINGS_MODULE='$1'.settings/;}' ./envs/.env.local.example
  sed -i'' -e '1,/ADDITIONAL_DOCKER_COMPOSE_PARAMS/{x;/first/s///;x;s/#ADDITIONAL_DOCKER_COMPOSE_PARAMS/ADDITIONAL_DOCKER_COMPOSE_PARAMS/;}' ./run.sh

  # Add required import
  sed -i '1,/from pathlib import Path/{x;/first/s///;x;s/from pathlib import Path/from pathlib import Path\nfrom os import environ/;}' ./app/$1/settings.py
  sed -i "1,/SECRET_KEY =.*/{x;/first/s///;x;s/SECRET_KEY =.*/SECRET_KEY = environ.get('DJANGO_SECRET_KEY', '')/;}" ./app/$1/settings.py
  sed -i "1,/ALLOWED_HOSTS = \[\]/{x;/first/s///;x;s/ALLOWED_HOSTS = \[\]/environ.get('DJANGO_ALLOWED_HOSTS', '').split(',')/;}" ./app/$1/settings.py
  sed -i "1,/'ENGINE': 'django.db.backends.sqlite3',/{x;/first/s///;x;s/'ENGINE': 'django.db.backends.sqlite3',/'ENGINE': 'django.db.backends.postgresql',/;}" ./app/$1/settings.py
  sed -i "1,/'NAME': BASE_DIR \/ 'db.sqlite3',/{x;/first/s///;x;s/'NAME': BASE_DIR \/ 'db.sqlite3',/'NAME': environ.get('DB_NAME', 'postgres'),\n        'USER': environ.get('DB_USER', 'postgres'),\n        'PASSWORD': environ.get('DB_PASS', 'postgres'),\n        'HOST': environ.get('DB_HOST', 'db'),\n        'PORT': environ.get('DB_PORT', '5432'),/;}" ./app/$1/settings.py
}



function init_local_files() {
  for f in $LOCAL_FILES
    do
      cp "$f" "${f::${#f}-8}"
    done

  # Create Django Secret Key
  DJANGO_SECRET_KEY=$(echo "from django.core.management.utils import get_random_secret_key;print(get_random_secret_key())" | ./run.sh -cc run --no-deps -e DJANGO_SECRET_KEY=temp --rm backend django-admin shell)
  sed -i "1,/DJANGO_SECRET_KEY=/{x;/first/s///;x;s/DJANGO_SECRET_KEY=/DJANGO_SECRET_KEY=\"$DJANGO_SECRET_KEY\"/;}" ./envs/.env.local
}

case $1 in
  help|-h|--help)
  echo "Usage (params with '*' are optional):"
  echo "./run.sh                                             -> UP containers in detach mode"
  echo "./run.sh bash|-sh                                    -> Open bash in main container"
  echo "./run.sh build|-b <params*>                          -> BUILD containers"
  echo "./run.sh build-force|-bf <params*>                   -> Force build containers (with params no-cache, pull)"
  echo "./run.sh custom_command|-cc                          -> Custom docker-compose command"
  echo "./run.sh create_django_secret|-crs                   -> Create Django Secret Key"
  echo "./run.sh create_superuser|-csu <password>            -> Create default super user"
  echo "./run.sh down|-dn                                    -> DOWN (stop and remove) containers"
  echo "./run.sh downv|-dnv                                  -> DOWN (stop and remove with volumes) containers"
  echo "./run.sh init|-i <project name> <django version*>    -> Initial setup and config development environment with creating new django project"
  echo "./run.sh help|-h                                     -> Show this help message"
  echo "./run.sh logs|-l <params*>                           -> LOGS from ALL containers"
  echo "./run.sh logsf|-lf <params*>                         -> LOGS from ALL containers with follow option"
  echo "./run.sh shell|-sl                                   -> Open shell in main container"
  echo "./run.sh shell_plus|-sp                              -> Open shell plus (only if django_extensions installed) in main container"
  echo "./run.sh makemigrate|-mm <params*>                   -> Make migrations and migrate inside main container"
  echo "./run.sh notebook|-nb                                -> Run notebook (only if django_extensions installed)"
  echo "./run.sh recreate|-rec <params*>                     -> Up and recreate containers"
  echo "./run.sh recreated|-recd <params*>                   -> Up and recreate containers in detach mode"
  echo "./run.sh restart|-r <params*>                        -> Restart containers"
  echo "./run.sh rm|-rm <params*>                            -> Remove force container"
  echo "./run.sh setup|-stp                                  -> Setup project for local development"
  echo "./run.sh stop|-s <params*>                           -> Stop containers"
  echo "./run.sh test|-t <params*>                           -> Run tests"
  echo "./run.sh up|-u <params*>                             -> UP containers with output"
  ;;
  bash|-sh)
  compose exec $MAIN_CONTAINER bash
  exit
  ;;
  build|-b)
  compose build ${@:2}
  exit
  ;;
  build-force|-bf)
  compose build --no-cache --pull ${@:2}
  exit
  ;;
  custom_command|-cc)
  compose ${@:2}
  exit
  ;;
  create_django_secret|-crs)
  echo "from django.core.management.utils import get_random_secret_key;print(get_random_secret_key())" | compose run --no-deps --rm backend django-admin shell
  exit
  ;;
  down|-dn)
  compose down
  exit
  ;;
  downv|-dnv)
  compose down -v
  exit
  ;;
  init|-i)
  # Set project name in ./run.sh
  if [ -z "$2" ]
    then
      echo "Please provide project name as param to this command. ./run.sh <project_name> e.g. ./run.sh foo_bar. Optional you can put Django version which you'd like to init project ./run.sh <project_name> <django_version> f.g './run.sh foo_bar 4'"
    exit
  fi

  if [ -n "$3" ]; then
    DJANGO_VERSION="Django==$3"
  else
    DJANGO_VERSION="Django>=3.2,<3.3"
  fi
  # Add django version to requirements 
  echo "${DJANGO_VERSION}" | cat - ./docker/requirements.txt > temp_req && mv temp_req ./docker/requirements.txt
  # Try init Django project
  if docker run --rm -v $(pwd)/app:/code -w /code -e DEFAULT_PERMS=$(id -u):$(id -g) python:3-slim /bin/bash -c "pip install \"$DJANGO_VERSION\" && django-admin startproject ${2} .&& chown -R \$DEFAULT_PERMS /code" ; then
    # Command succeeded
    setup_local_project $2
    ./run.sh -stp $2
  else
    # Command failed
    sed "/${DJANGO_VERSION}/d" ./docker/requirements.txt > temp_req && mv temp_req ./docker/requirements.txt
  fi 
  
  exit
  ;;
  create_superuser|-csu)
  if [ -z "$2" ]; then
    echo -e "You must provide an admin password as param f.g. \n$ ./run.sh -csu admin"
    exit
  fi
  echo "import os; from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('admin', 'admin@email.com', '$2') if not User.objects.filter(username='admin').exists() else print('Admin account exist.')" | compose exec -T $MAIN_CONTAINER "python manage.py shell"
  exit
  ;;
  logs|-l)
  compose logs ${@:2}
  exit
  ;;
  logsf|-lf)
  compose logs -f ${@:2}
  exit
  ;;
  shell|-sl)
  compose exec $MAIN_CONTAINER "python manage.py shell"
  exit
  ;;
  shell_plus|-sp)
  compose exec $MAIN_CONTAINER "python manage.py shell_plus"
  exit
  ;;
  makemigrate|-mm)
  compose exec $MAIN_CONTAINER django-admin makemigrations
  compose exec $MAIN_CONTAINER django-admin migrate
  exit
  ;;
  notebook|-nb)
  compose exec $MAIN_CONTAINER django-admin shell_plus --notebook
  exit
  ;;
  recreate|-rec)
  compose up --force-recreate ${@:2}
  exit
  ;;
  recreated|-recd)
  compose up --force-recreate -d ${@:2}
  exit
  ;;
  restart|-r)
  compose restart ${@:2}
  exit
  ;;
  rm|-rm)
  compose rm -fv ${@:2}
  exit
  ;;
  setup|-stp)
  init_local_files $2
  echo "Build project"
  ./run.sh build
  echo "Project setup completed. Now you can run containers with './run.sh' or './run.sh -u' (with live output)."
  exit
  ;;
  stop|-s)
  compose stop ${@:2}
  exit
  ;;
  test|-t)
  compose exec $MAIN_CONTAINER "python manage.py test ${@:2}"
  exit
  ;;
  up|-u)
  compose up ${@:2}
  exit
  ;;
  *)
  compose up -d ${@:2}
  exit
  ;;
esac
