FROM rivia/jupyterlab:latest

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

ENV DEBIAN_VERSION=stretch

RUN apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    gnupg2 apt-transport-https && \
    curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add - && \
    echo "deb https://repos.influxdata.com/debian ${DEBIAN_VERSION} stable" >>/etc/apt/sources.list.d/influxdb.list && \
    apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    redis-server \
    mysql-client \
    influxdb \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    && \
    conda install --quiet -y sqlalchemy redis-py requests && \
    conda clean --all -f -y && \
    pip install --no-cache-dir influxdb

ENV REDIS_HOST=0.0.0.0 REDIS_PORT=6379
RUN echo "" >>/opt/conda/etc/supervisord.conf && \
    echo "[program:redis]" >>/opt/conda/etc/supervisord.conf && \
    echo "user=root" >>/opt/conda/etc/supervisord.conf && \
    echo "command=redis-server --bind ${REDIS_HOST} --port ${REDIS_PORT}" >>/opt/conda/etc/supervisord.conf && \
    echo "autostart=true" >>/opt/conda/etc/supervisord.conf && \
    echo "autorestart=true" >>/opt/conda/etc/supervisord.conf && \
    echo "stdout_logfile=/var/log/redis/stdout.log" >>/opt/conda/etc/supervisord.conf && \
    echo "stderr_logfile=/var/log/redis/stderr.log" >>/opt/conda/etc/supervisord.conf

EXPOSE ${REDIS_PORT}

ENTRYPOINT [ "/usr/bin/tini", "--" ]

CMD ["/opt/conda/bin/supervisord", "-c", "/opt/conda/etc/supervisord.conf"]
