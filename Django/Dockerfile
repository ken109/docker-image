FROM nginx

COPY --from=continuumio/miniconda3 /opt/conda /opt/conda
ENV PATH $PATH:/opt/conda/bin

RUN conda config --append channels conda-forge; \
    conda install -y \
        django \
        mysqlclient; \
    conda install -y -c conda-forge \
        uwsgi \
        libiconv; \
    conda clean --all; \
    rm -rf /usr/share/nginx/html/*

WORKDIR /usr/share/nginx/html

COPY settings.py /usr/src/
COPY uwsgi.ini /usr/src/
COPY default.conf /etc/nginx/conf.d

COPY docker-python-entrypoint.sh /usr/local/bin

ENTRYPOINT ["docker-python-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]