FROM python:3.6.0-alpine

WORKDIR /app
ADD . /app

RUN apk update \
    && apk add --no-cache --virtual tmp gcc musl-dev \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /app/requirements.txt \
    && apk del tmp

ENV POST_DATABASE_HOST post_db
ENV POST_DATABASE posts

ENTRYPOINT ["python3", "post_app.py"]
