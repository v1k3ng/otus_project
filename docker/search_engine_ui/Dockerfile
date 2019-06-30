FROM python:3.6.0-alpine

WORKDIR /app
ADD . /app

RUN apk update \
    && apk add --no-cache --virtual tmp gcc musl-dev \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /app/requirements.txt \
    && apk del tmp

# ENTRYPOINT ["python3", "post_app.py"]
# ENTRYPOINT [ "cd ui && FLASK_APP=ui.py gunicorn ui:app -b 0.0.0.0" ]
