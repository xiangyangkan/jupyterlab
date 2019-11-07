FROM continuumio/miniconda3:latest

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH
ENV DEBIAN_VERSION=buster
ENV PYTHON_VERSION 3.7
ENV CONDA_DIR=/opt/conda

# Needed for string substitution
SHELL ["/bin/bash", "-c"]


# change timezone
ARG TZ="Asia/Shanghai"
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo ${TZ} > /etc/timezone


# change debian source
# sometimes need chmod 777 /tmp to avoid gpg error
RUN chmod 777 /tmp && \
    mv /etc/apt/sources.list /etc/apt/sources.list.bak && \
    echo "deb http://mirrors.aliyun.com/debian ${DEBIAN_VERSION} main contrib non-free" >>/etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian ${DEBIAN_VERSION} main contrib non-free" >>/etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian ${DEBIAN_VERSION}-updates main contrib non-free" >>/etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian ${DEBIAN_VERSION}-updates main contrib non-free" >>/etc/apt/sources.list && \
    echo "deb http://mirrors.aliyun.com/debian-security/ ${DEBIAN_VERSION}/updates main non-free contrib" >>/etc/apt/sources.list && \
    echo "deb-src http://mirrors.aliyun.com/debian-security/ ${DEBIAN_VERSION}/updates main non-free contrib" >>/etc/apt/sources.list


# extra dependencies
COPY debian_requirements.txt /
RUN apt-get update --fix-missing && \
    cat /debian_requirements.txt | xargs apt-get install -y --no-install-recommends --allow-unauthenticated && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* \
    && \
    conda config --add channels conda-forge && \
    conda config --set show_channel_urls yes && \
    conda install --quiet -y supervisor notebook jupyterhub jupyterlab && \
    conda clean --all -f -y


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


# proxy config
# if you want to start proxy, run `service v2ray start`
RUN curl -L -o /tmp/go.sh https://install.direct/go.sh && \
    chmod +x /tmp/go.sh && \
    /tmp/go.sh
COPY v2ray_config.json /etc/v2ray/
RUN mv /etc/v2ray/v2ray_config.json /etc/v2ray/config.json


# jupyter lab config
COPY jupyter_notebook_config.py /root/.jupyter/
COPY run_jupyter.sh /
RUN chmod +x /run_jupyter.sh && \
    pip install --no-cache-dir jupyter_http_over_ws && \
    jupyter serverextension enable --py jupyter_http_over_ws && \
    python -m ipykernel.kernelspec
EXPOSE 8888


# Julia dependencies
# install Julia packages in /opt/julia instead of $HOME
ENV JULIA_PKGDIR=/opt/julia
ENV JULIA_VERSION=1.2.0
RUN mkdir /opt/julia-${JULIA_VERSION} && \
    cd /tmp && \
    wget -q https://julialang-s3.julialang.org/bin/linux/x64/`echo ${JULIA_VERSION} | cut -d. -f 1,2`/julia-${JULIA_VERSION}-linux-x86_64.tar.gz && \
    echo "926ced5dec5d726ed0d2919e849ff084a320882fb67ab048385849f9483afc47 *julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | sha256sum -c - && \
    tar xzf julia-${JULIA_VERSION}-linux-x86_64.tar.gz -C /opt/julia-${JULIA_VERSION} --strip-components=1 && \
    rm /tmp/julia-${JULIA_VERSION}-linux-x86_64.tar.gz
RUN ln -fs /opt/julia-*/bin/julia /usr/local/bin/julia


# Show Julia where conda libraries are \
RUN mkdir /etc/julia && \
    echo "push!(Libdl.DL_LOAD_PATH, \"$CONDA_DIR/lib\")" >> /etc/julia/juliarc.jl && \
    # Create JULIA_PKGDIR \
    mkdir $JULIA_PKGDIR && \
    chown root $JULIA_PKGDIR && \
    fix-permissions $JULIA_PKGDIR


# Add Julia packages. Only add HDF5 if this is not a test-only build since
# it takes roughly half the entire build time of all of the images on Travis
# to add this one package and often causes Travis to timeout.
#
# Install IJulia as jovyan and then move the kernelspec out
# to the system share location. Avoids problems with runtime UID change not
# taking effect properly on the .local folder in the jovyan home dir.
RUN julia -e 'import Pkg; Pkg.update()' && \
    julia -e "using Pkg; pkg\"add IJulia\"; pkg\"precompile\"" && \
    # move kernelspec out of home \
    mv $HOME/.local/share/jupyter/kernels/julia* $CONDA_DIR/share/jupyter/kernels/ && \
    chmod -R go+rx $CONDA_DIR/share/jupyter && \
    rm -rf $HOME/.local && \
    fix-permissions $JULIA_PKGDIR $CONDA_DIR/share/jupyter

CMD ["/opt/conda/bin/supervisord", "-c", "/opt/conda/etc/supervisord.conf"]

