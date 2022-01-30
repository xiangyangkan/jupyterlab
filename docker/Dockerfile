FROM continuumio/miniconda3:4.10.3

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH
ENV DEBIAN_VERSION=buster
ENV PYTHON_VERSION 3.8

# Needed for string substitution
SHELL ["/bin/bash", "-c"]


# change timezone
ARG TZ="Asia/Shanghai"
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone


# change debian and pip source
# sometimes need chmod 777 /tmp to avoid gpg error
#RUN chmod 777 /tmp && \
#    mv /etc/apt/sources.list /etc/apt/sources.list.bak && \
#    echo "deb http://mirrors.aliyun.com/debian ${DEBIAN_VERSION} main contrib non-free" >>/etc/apt/sources.list && \
#    echo "deb-src http://mirrors.aliyun.com/debian ${DEBIAN_VERSION} main contrib non-free" >>/etc/apt/sources.list && \
#    echo "deb http://mirrors.aliyun.com/debian ${DEBIAN_VERSION}-updates main contrib non-free" >>/etc/apt/sources.list && \
#    echo "deb-src http://mirrors.aliyun.com/debian ${DEBIAN_VERSION}-updates main contrib non-free" >>/etc/apt/sources.list && \
#    echo "deb http://mirrors.aliyun.com/debian-security/ ${DEBIAN_VERSION}/updates main non-free contrib" >>/etc/apt/sources.list && \
#    echo "deb-src http://mirrors.aliyun.com/debian-security/ ${DEBIAN_VERSION}/updates main non-free contrib" >>/etc/apt/sources.list \
#    && \
#    mkdir /root/.pip && \
#    echo "[global] index-url=https://pypi.tuna.tsinghua.edu.cn/simple" >>/root/.pip/pip.conf && \
#    echo "[install] trusted-host=pypi.tuna.tsinghua.edu.cn" >>/root/.pip/pip.conf


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
    conda install --quiet -y --file /python_requirements.txt && \
    conda clean --all -f -y

# jupyter labextension
ENV NODEJS_VERSION=17.4.0
ENV NODEJS_DIR=/opt
ARG NODEJS_MIRROR="https://nodejs.org/dist"
RUN set -x && \
    node_tar="node-v${NODEJS_VERSION}-linux-x64.tar.gz" && \
    wget --quiet "${NODEJS_MIRROR}/v${NODEJS_VERSION}/${node_tar}" && \
    tar -zxvf "${NODEJS_DIR}" -C ${NODEJS_DIR} && \
    rm "${NODEJS_DIR}" && \
    ln -s "${NODEJS_DIR}/node-v${NODEJS_VERSION}-linux-x64/bin/node" /usr/bin/node && \
    ln -s "${NODEJS_DIR}/node-v${NODEJS_VERSION}-linux-x64/bin/npm" /usr/bin/npm && \
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

CMD ["/opt/conda/bin/supervisord", "-c", "/opt/conda/etc/supervisord.conf"]