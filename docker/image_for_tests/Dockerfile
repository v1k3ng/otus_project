FROM alpine:3.7

WORKDIR /app

RUN apk add --update --no-cache gcc musl-dev python3 python3-dev \
    && pip3 install --upgrade pip

CMD /bin/ash
