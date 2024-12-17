FROM ubuntu:24.04

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH
ENV PYTHON_VERSION 3.11

# Needed for string substitution
SHELL ["/bin/bash", "-c"]


# change timezone
ARG TZ="UTC"
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone


# install conda
ENV CONDA_DIR=/opt/conda
ENV PATH="${CONDA_DIR}/bin:${PATH}"
ARG CONDA_MIRROR=https://repo.anaconda.com/miniconda
# Specify Python 3.11 Version
ARG CONDA_VERSION=24.9.2-0
RUN set -x && \
    apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends --allow-unauthenticated wget && \
    apt-get clean && \
    miniforge_arch=$(uname -m) && \
    miniforge_installer="Miniconda3-py311_${CONDA_VERSION}-Linux-${miniforge_arch}.sh" && \
    wget --quiet --no-check-certificate "${CONDA_MIRROR}/${miniforge_installer}" && \
    /bin/bash "${miniforge_installer}" -f -b -p "${CONDA_DIR}" && \
    rm "${miniforge_installer}" && \
    # Conda configuration see https://conda.io/projects/conda/en/latest/configuration.html
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    mamba list python | grep '^python ' | tr -s ' ' | cut -d ' ' -f 1,2 >> "${CONDA_DIR}/conda-meta/pinned" && \
    # Using conda to update all packages: https://github.com/mamba-org/mamba/issues/1092
    conda install numpy conda-pack && \
    conda clean --all -f -y


# extra dependencies
# use pip instead of conda :  pip install --no-cache-dir -r /python_requirements.txt
ENV PACKAGES supervisor jupyterlab numpy pandas requests graph-tool
COPY python_requirements.txt debian_requirements.txt /
RUN apt-get update --fix-missing && \
    cat /debian_requirements.txt | xargs apt-get install -y --no-install-recommends --allow-unauthenticated && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    && \
    conda config --add channels conda-forge && \
    conda config --set show_channel_urls yes && \
    conda install --quiet -y $PACKAGES && \
    conda clean --all -f -y

# jupyter labextension
# replace old version installed via conda
ENV NODEJS_VERSION=22.11.0
ENV NODEJS_DIR=/opt
ARG NODEJS_MIRROR="https://nodejs.org/dist"
RUN set -x && \
    node_tar="node-v${NODEJS_VERSION}-linux-x64.tar.gz" && \
    wget --quiet --no-check-certificate "${NODEJS_MIRROR}/v${NODEJS_VERSION}/${node_tar}" && \
    tar -zxvf "${node_tar}" -C ${NODEJS_DIR} && \
    rm "${node_tar}" && \
    rm -rf "/opt/conda/bin/node" && \
    rm -rf "/opt/conda/bin/npm" && \
    ln -s "${NODEJS_DIR}/node-v${NODEJS_VERSION}-linux-x64/bin/node" /opt/conda/bin/node && \
    ln -s "${NODEJS_DIR}/node-v${NODEJS_VERSION}-linux-x64/bin/npm" /opt/conda/bin/npm && \
    npm cache clean --force

# install go

ENV GOPATH=/usr/local/go
ENV PATH=$PATH:$GOPATH/bin
RUN apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y software-properties-common gnupg && \
    add-apt-repository -y ppa:longsleep/golang-backports && \
    apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y \
      golang \
      libssl-dev \
      libmbedtls-dev \
      autoconf

# install solc
RUN apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y software-properties-common gpg gpg-agent && \
    add-apt-repository ppa:ethereum/ethereum && \
    apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y solc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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
COPY jupyter_server_config.py /root/.jupyter/
COPY jupyter_notebook_config.py /root/.jupyter/
COPY run_jupyter.sh /
RUN chmod +x /run_jupyter.sh && \
    pip install --upgrade requests && \
    pip install --no-cache-dir jupyterlab jupyter_http_over_ws && \
    jupyter-server extension enable --py jupyter_http_over_ws && \
    python -m ipykernel.kernelspec
EXPOSE 8888

# brownie installation
RUN python3 -m pip install --user pipx && \
    pip install Cython~=0.29 blosc2~=2.0.0 && \
    pip install --no-build-isolation pyyaml==5.4.1 && \
    python3 -m pipx ensurepath
RUN /root/.local/bin/pipx install eth-brownie

# foundary installation
RUN curl -L https://foundry.paradigm.xyz | bash

# graph-node installation
#RUN npm install -g yarn @graphprotocol/graph-cli @graphprotocol/graph-ts && \
#    npm cache clean --force
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg -o yarn.asc && \
    mv yarn.asc /etc/apt/trusted.gpg.d/ && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update --fix-missing && apt-get install --no-install-recommends --allow-unauthenticated -y libsecret-1-dev yarn && \
    yarn global add @graphprotocol/graph-cli && \
    yarn cache clean && \
    apt-get clean

CMD ["/opt/conda/bin/supervisord", "-c", "/opt/conda/etc/supervisord.conf"]