#!/bin/bash
set -e

echo "${0}: wait for postgres."
bash ../docker/wait-for-it.sh "$DB_HOST":"$DB_PORT"

echo "${0}: running migrations."
python manage.py migrate --noinput

# echo "${0}: collecting statics."
# python manage.py collectstatic --noinput

echo "${0}: starting $PROJECT_NAME."
gunicorn $PROJECT_NAME.wsgi:application \
   --name finteq_backend \
   --bind 0.0.0.0:8000 \
   --timeout 600 \
   --workers 3 \
   --log-level=info
"$@"