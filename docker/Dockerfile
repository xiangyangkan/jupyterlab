FROM continuumio/miniconda3:latest

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH
ENV PYTHON_VERSION 3.7

# change debian and pip source
RUN mv /etc/apt/sources.list /etc/apt/sources.list.bak && \
    echo "deb http://mirrors.aliyun.com/debian stretch main contrib non-free" >>/etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian stretch main contrib non-free" >>/etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian stretch-updates main contrib non-free" >>/etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian stretch-updates main contrib non-free" >>/etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian-security/ stretch/updates main non-free contrib" >>/etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian-security/ stretch/updates main non-free contrib" >>/etc/apt/sources.list \
    && \
    mkdir /root/.pip && \
    echo "[global] index-url=https://pypi.tuna.tsinghua.edu.cn/simple" >>/root/.pip/pip.conf && \
    echo "[install] trusted-host=pypi.tuna.tsinghua.edu.cn" >>/root/.pip/pip.conf


# extra dependencies
# use pip instead of conda :  pip install --no-cache-dir -r /python_requirements.txt
COPY python_requirements.txt debian_requirements.txt /
RUN apt-get update --fix-missing && \
    cat /debian_requirements.txt | xargs apt-get install -y --no-install-recommends --allow-unauthenticated && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    && \
    conda config --add channels conda-forge && \
    conda config --set show_channel_urls yes && \
    conda update -n base -c defaults conda && \
    conda update --all -y && \
    conda install --quiet -y --file /python_requirements.txt && \
    conda install --quiet -y requests && \
    npm config set registry http://registry.npm.taobao.org/ && \
    conda clean --all -f -y \
    && \
    jupyter labextension install \
        @jupyter-widgets/jupyterlab-manager \
        @jupyterlab/hub-extension \
        jupyter-matplotlib \
        && \
    npm cache clean --force


# jupyter code formatter
RUN conda install --quiet -y black jupyterlab_code_formatter && \
    jupyter labextension install @ryantam626/jupyterlab_code_formatter && \
    jupyter serverextension enable --py jupyterlab_code_formatter && \
    conda clean --all -f -y && \
    npm cache clean --force
COPY shortcuts.jupyterlab-settings /root/.jupyter/lab/user-settings/@jupyterlab/shortcuts-extension/shortcuts.jupyterlab-settings


# deal with vim and matplotlib Mojibake
COPY simhei.ttf /opt/conda/lib/python${PYTHON_VERSION}/site-packages/matplotlib/mpl-data/fonts/ttf
RUN echo "set encoding=utf-8 nobomb" >> /etc/vim/vimrc && \
    echo "set termencoding=utf-8" >> /etc/vim/vimrc && \
    echo "set fileencodings=utf-8,gbk,utf-16le,cp1252,iso-8859-15,ucs-bom" >> /etc/vim/vimrc && \
    echo "set fileformats=unix,dos,mac" >> /etc/vim/vimrc && \
    rm -rf /root/.cache/matplotlib


# supervisor config
RUN mkdir /var/run/sshd /var/log/supervisor
COPY supervisord.conf /opt/conda/etc/supervisord.conf


# SSH config
RUN apt-get update --fix-missing && apt-get install --no-install-recommends --allow-unauthenticated -y \
    openssh-server pwgen && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    sed -i "s/.*UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g" /etc/ssh/sshd_config && \
    sed -i "s/.*UsePAM.*/UsePAM no/g" /etc/ssh/sshd_config && \
    sed -i "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config && \
    sed -i "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
COPY set_root_pw.sh run_ssh.sh /
RUN chmod +x /*.sh && sed -i -e 's/\r$//' /*.sh
ENV AUTHORIZED_KEYS **None**
EXPOSE 22


# jupyter lab config
COPY jupyter_notebook_config.py /root/.jupyter/
COPY run_jupyter.sh /
RUN chmod +x /run_jupyter.sh && \
    pip install --no-cache-dir jupyter_http_over_ws && \
    jupyter serverextension enable --py jupyter_http_over_ws && \
    python -m ipykernel.kernelspec
EXPOSE 8888


# install mysql-server, redis-server and influxdb
ARG DB
ENV DEBIAN_VERSION=stretch
RUN test -z ${DB} || (apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    gnupg2 apt-transport-https && \
    curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add - && \
    echo "deb https://repos.influxdata.com/debian ${DEBIAN_VERSION} stable" >>/etc/apt/sources.list.d/influxdb.list && \
    apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    mysql-server \
    redis-server \
    influxdb \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /etc/apt/sources.list.d/influxdb.list \
    && \
    printf "\n\
    [program:mysql-server] \n\
    user=root \n\
    command=mysql-server --character-set-server=utf8mb4 --max-allowed-packet=256M" \
    >>/opt/conda/etc/supervisord.conf \
    && \
    printf "\n\
    [program:redis-server] \n\
    user=root \n\
    command=redis-server" \
    >>/opt/conda/etc/supervisord.conf \
    && \
    printf "\n\
    [program:influxd] \n\
    user=root \n\
    command=influxd" \
    >>/opt/conda/etc/supervisord.conf)


ARG ML
RUN [[ ${ML} != cpu ]] || (conda install --quiet -y \
      scikit-learn \
      scikit-image \
      tensorflow \
      keras \
      && \
    conda clean --all -f -y)

RUN [[ ${ML} != gpu ]] || (conda install --quiet -y \
      scikit-learn \
      scikit-image \
      cudatoolkit \
      cudnn \
      tensorflow-gpu \
      keras \
      && \
    conda clean --all -f -y)

ENTRYPOINT [ "/usr/bin/tini", "--" ]

CMD ["/opt/conda/bin/supervisord", "-c", "/opt/conda/etc/supervisord.conf"]
