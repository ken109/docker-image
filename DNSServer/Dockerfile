FROM python:slim as builder

WORKDIR /usr/src/app
COPY requirements.txt requirements.txt

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		build-essential \
	; \
	rm -rf /var/lib/apt/lists/*; \
	pip install --no-cache-dir -r requirements.txt

FROM python:slim

COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/lib /usr/local/lib

COPY watcher.ini /usr/src
COPY watcher.py /usr/local/bin
COPY refresh.sh /usr/local/bin

WORKDIR /usr/src/app
COPY main.py main.py
COPY docker-entrypoint.sh docker-entrypoint.sh

EXPOSE 53

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD [ "python", "./main.py" ]
