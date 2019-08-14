FROM rivia/jupyterlab:latest

MAINTAINER Xiangyang Kan <xiangyangkan@outlook.com>

RUN conda install --quiet -y \
    scikit-learn \
    scikit-image \
    tensorflow \
    keras \
    && \
    conda clean --all -f -y

ENTRYPOINT [ "/usr/bin/tini", "--" ]

CMD ["/opt/conda/bin/supervisord", "-c", "/opt/conda/etc/supervisord.conf"]