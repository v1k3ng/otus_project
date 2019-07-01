FROM alpine:3.7

WORKDIR /app
ADD . /app

RUN apk add --update --no-cache gcc musl-dev python3 python3-dev \
    && pip3 install --upgrade pip \
    && pip3 install -r /app/requirements.txt

CMD python3 -u crawler/crawler.py https://vitkhab.github.io/search_engine_test_site/

# FROM python:3.6.0-alpine

# WORKDIR /app
# ADD . /app

# RUN apk update \
#     && apk add --no-cache --virtual tmp gcc musl-dev \
#     && pip install --no-cache-dir --upgrade pip \
#     && pip install --no-cache-dir -r /app/requirements.txt \
#     && apk del tmp

# ENTRYPOINT [ "EXCLUDE_URLS='.*github.com' && python -u crawler/crawler.py https://vitkhab.github.io/search_engine_test_site/" ]
