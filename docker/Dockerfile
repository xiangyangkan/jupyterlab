ARG BASE_IMAGE=ubuntu:24.04

# add sshd support
# no key arguement for the base image
FROM ${BASE_IMAGE} as base

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Needed for string substitution
SHELL ["/bin/bash", "-c"]

# change timezone
ARG TZ="UTC"
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone

# supervisor config
RUN mkdir -p /var/run/sshd
COPY supervisord.conf /

# SSH config
ARG UBUNTU_MIRROR=http://launchpadlibrarian.net
ARG UPDATE_CUDA_SOURCE=true
ARG ARCH=x86_64
RUN apt-get update --fix-missing && apt-get install --allow-unauthenticated -y \
    openssh-server pwgen supervisor proxychains redsocks libnfnetlink0 && \
    if [ "${ARCH}" = "aarch64" ]; then \
        iptables_installer="iptables_1.6.0-2ubuntu3_arm64.deb"; \
        libxtables_installer="libxtables11_1.6.0-2ubuntu3_arm64.deb"; \
        wget --quiet "${UBUNTU_MIRROR}/240591460/${iptables_installer}"; \
        wget --quiet "${UBUNTU_MIRROR}/240591461/${libxtables_installer}"; \
    else \
        iptables_installer="iptables_1.6.0-2ubuntu3_amd64.deb"; \
        libxtables_installer="libxtables11_1.6.0-2ubuntu3_amd64.deb"; \
        wget --quiet "${UBUNTU_MIRROR}/240591163/${iptables_installer}"; \
        wget --quiet "${UBUNTU_MIRROR}/240591164/${libxtables_installer}"; \
    fi && \
    dpkg -i ${libxtables_installer} ${iptables_installer} && \
    rm ${libxtables_installer} ${iptables_installer} && \
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

COPY proxychains.conf /etc/proxychains.conf
COPY redsocks.conf /etc/redsocks.conf
COPY configure_repos.sh /configure_repos.sh
RUN chmod a+rwx /etc/bash.bashrc && chmod +x /configure_repos.sh
RUN env | egrep -v "^(LS_COLORS=|SSH_CONNECTION=|USER=|PWD=|HOME=|SSH_CLIENT=|SSH_TTY=|MAIL=|TERM=|SHELL=|SHLVL=|LOGNAME=|PS1=|_=)" > /etc/environment

CMD ["/usr/bin/supervisord", "-c", "/supervisord.conf"]

# add conda
# key arguement for the conda image: PYTHON_VERSION, CONDA_VERSION
FROM ${BASE_IMAGE} as conda

# install conda
ARG PYTHON_VERSION=3.12
ENV CONDA_DIR=/opt/conda
ENV PATH="${CONDA_DIR}/bin:${PATH}"
ARG CONDA_MIRROR=https://repo.anaconda.com/miniconda
ARG CONDA_VERSION=25.1.1-0
RUN set -x && \
    # Miniforge installer
    miniforge_arch=$(uname -m) && \
    miniforge_installer="Miniconda3-py${PYTHON_VERSION//./}_${CONDA_VERSION}-Linux-${miniforge_arch}.sh" && \
    wget --quiet "${CONDA_MIRROR}/${miniforge_installer}" && \
    /bin/bash "${miniforge_installer}" -f -b -p "${CONDA_DIR}" && \
    rm "${miniforge_installer}" && \
    # Conda configuration see https://conda.io/projects/conda/en/latest/configuration.html
    conda config --system --set auto_update_conda false && \
    conda config --system --set show_channel_urls true && \
    mamba list python | grep '^python ' | tr -s ' ' | cut -d ' ' -f 1,2 >> "${CONDA_DIR}/conda-meta/pinned" && \
    # Using conda to update all packages: https://github.com/mamba-org/mamba/issues/1092
    conda clean --all -f -y

# add cmake and go-lang
# key arguement for the build image: NODEJS_VERSION, CMAKE_VERSION, BUF_VERSION
FROM ${BASE_IMAGE} as build

# install nodejs
ARG NODEJS_VERSION=23.7.0
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

# install cmake
ARG CMAKE_VERSION=3.31.5
ARG CMAKE_MIRROR=https://github.com/Kitware/CMake/releases/download
ENV CMAKE_DIR=/usr/local
RUN set -x && \
    cmake_sh="cmake-${CMAKE_VERSION}-Linux-x86_64.sh" && \
    wget --quiet "${CMAKE_MIRROR}/v${CMAKE_VERSION}/${cmake_sh}" && \
    chmod +x ${cmake_sh} && \
    ./${cmake_sh} --prefix=${CMAKE_DIR} --exclude-subdir --skip-license && \
    rm ${cmake_sh}

# install go-lang, cargo and buf
ARG BUF_VERSION=1.50.0
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
      autoconf \
      && \
    curl https://sh.rustup.rs -sSf | sh -s -- -y && source "$HOME/.cargo/env" && \
    go install github.com/bufbuild/buf/cmd/buf@v$BUF_VERSION && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# install substreams
ARG SUBSTREAMS_VERSION=1.12.4
ENV SUBSTREAMS_REPO="https://github.com/streamingfast/substreams/releases/download/v${SUBSTREAMS_VERSION}"
RUN substreams_file="substreams_linux_x86_64.tar.gz" && \
    wget --quiet "${SUBSTREAMS_REPO}/${substreams_file}" && \
    tar -xzf "${substreams_file}" -C /usr/local/bin && \
    rm "${substreams_file}"

# add evm, brownie, foundary, graph-node
FROM ${BASE_IMAGE} as evm
# install solc
RUN apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y software-properties-common gpg gpg-agent && \
    add-apt-repository ppa:ethereum/ethereum && \
    apt-get update --fix-missing && \
    apt-get install --no-install-recommends --allow-unauthenticated -y solc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# brownie installation
RUN python3 -m pip install --user pipx && \
    pip install Cython~=0.29 blosc2~=2.0.0 && \
    pip install --no-build-isolation pyyaml==5.4.1 && \
    python3 -m pipx ensurepath
RUN /root/.local/bin/pipx install eth-brownie

# foundary installation
RUN curl -L https://foundry.paradigm.xyz | bash

# graph-node installation
RUN npm install -g yarn @graphprotocol/graph-cli @graphprotocol/graph-ts && \
    npm cache clean --force
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg -o yarn.asc && \
    mv yarn.asc /etc/apt/trusted.gpg.d/ && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update --fix-missing && apt-get install --no-install-recommends --allow-unauthenticated -y libsecret-1-dev yarn && \
    yarn global add @graphprotocol/graph-cli && \
    yarn cache clean && \
    apt-get clean

# add extra dependencies and jupyter lab
# key arguement for the devel image: PYTHON_VERSION
FROM ${BASE_IMAGE} as devel

# extra dependencies
ARG PYTHON_VERSION=3.12
COPY python_requirements.txt debian_requirements.txt /
RUN apt-get update --fix-missing && \
    cat /debian_requirements.txt | xargs apt-get install -y --no-install-recommends --allow-unauthenticated && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --upgrade pip && \
    ln -snf /usr/local/bin/pip /usr/bin/pip${PYTHON_VERSION} && \
    pip install --no-cache-dir -r /python_requirements.txt

# jupyter lab config
COPY jupyter_server_config.py /root/.jupyter/
COPY jupyter_notebook_config.py /root/.jupyter/
COPY run_jupyter.sh /
RUN chmod +x /run_jupyter.sh && \
    pip install --upgrade requests && \
    pip install --no-cache-dir jupyter_http_over_ws && \
    jupyter-server extension enable --py jupyter_http_over_ws && \
    python3 -m ipykernel.kernelspec
EXPOSE 8888

# deal with vim and matplotlib Mojibake
COPY simhei.ttf /opt/conda/lib/python${PYTHON_VERSION}/site-packages/matplotlib/mpl-data/fonts/ttf/
RUN echo "set encoding=utf-8 nobomb" >> /etc/vim/vimrc && \
    echo "set termencoding=utf-8" >> /etc/vim/vimrc && \
    echo "set fileencodings=utf-8,gbk,utf-16le,cp1252,iso-8859-15,ucs-bom" >> /etc/vim/vimrc && \
    echo "set fileformats=unix,dos,mac" >> /etc/vim/vimrc && \
    rm -rf /root/.cache/matplotlib