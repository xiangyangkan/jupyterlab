FROM rivia/jupyterlab:4.10.3

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

# install solc
RUN apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y software-properties-common && \
    add-apt-repository ppa:ethereum/ethereum && \
    apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y solc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# install web3py
RUN pip isntall  --no-cache-dir web3

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]