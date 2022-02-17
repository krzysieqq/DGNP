FROM python:3.8-slim as prod

LABEL maintainer="Krzysieqq (Krzysztof Owsieniuk krzysztof.owsieniuk@gmail.com)"
LABEL url="https://github.com/krzysieqq/DGNP"

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV PYTHONPATH "${PYTHONPATH}:/code/app"

RUN groupadd user
RUN useradd -ms /bin/bash -g user user

RUN mkdir /code /code/static /code/media /code/configs /code/app

COPY docker/wait-for-it.sh /code/docker/wait-for-it.sh
COPY docker/entrypoint.sh /code/docker/entrypoint.sh

COPY docker/requirements.txt /code/docker/requirements.txt

RUN chmod +x /code/docker/*.sh

RUN pip install --upgrade pip

RUN pip install --no-cache-dir -r /code/docker/requirements.txt

COPY app/ /code/app/

RUN chown -R user:user /code/docker/wait-for-it.sh
RUN chown -R user:user /code/app /code/static /code/media

USER user
WORKDIR /code/app

FROM prod as local

USER root

COPY docker/requirements.local.txt /code/docker/requirements.local.txt
RUN pip install --no-cache-dir -r /code/docker/requirements.local.txt

USER user
