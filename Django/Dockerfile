FROM nginx/unit:1.17.0-python3.7

COPY --from=continuumio/miniconda3 /opt/conda /opt/conda
ENV PATH $PATH:/opt/conda/bin

RUN mkdir -p /var/www/django; \
    conda install -y django mysqlclient
VOLUME /var/www/django
WORKDIR /var/www/django

COPY settings.py /usr/src/
COPY unit.conf.json /usr/src/

COPY docker-python-entrypoint.sh /usr/local/bin
ENTRYPOINT ["docker-python-entrypoint.sh"]