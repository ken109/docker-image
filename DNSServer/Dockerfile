FROM python:slim as builder

WORKDIR /usr/src/app
COPY . .

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

WORKDIR /usr/src/app
COPY main.py main.py

EXPOSE 53

CMD [ "python", "./main.py" ]