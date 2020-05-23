FROM nginx

COPY --from=continuumio/miniconda3 /opt/conda /opt/conda
ENV PATH $PATH:/opt/conda/bin

RUN apt-get update; \
    apt-get install -y wget gnupg unzip; \
    sh -c 'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'; \
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -; \
    apt-get update; \
    apt-get install -y google-chrome-stable; \
    rm -rf /var/lib/apt/lists/*; \
    google-chrome --version

RUN conda config --append channels conda-forge; \
    conda install -y \
        django \
        mysqlclient \
        selenium; \
    conda install -y -c conda-forge \
        uwsgi \
        libiconv; \
    conda clean --all; \
    pip install \
        pyinotify \
        bs4 \
        django-widgets-improved \
        chromedriver-binary=="$(echo $(google-chrome --version | awk {'print $3'} | cut -d '.' -f 1).*)" \
    ; \
    rm -rf /root/.cache/pip; \
    rm -rf /usr/share/nginx/html/*

WORKDIR /usr/share/nginx/html

COPY settings.py /usr/src
COPY uwsgi.ini /usr/src
COPY watcher.ini /usr/src
COPY watcher.py /usr/local/bin
COPY default.conf /etc/nginx/conf.d

COPY docker-python-entrypoint.sh /usr/local/bin

ENTRYPOINT ["docker-python-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]