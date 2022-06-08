FROM node:18-slim AS node-installer
RUN npm install -global textlint textlint-rule-preset-ja-technical-writing textlint-filter-rule-comments textlint-filter-rule-whitelist


FROM ubuntu:22.04 AS python-installer
# setting user
ARG UID=1000
RUN groupadd jupytex && useradd -m -u ${UID} jupytex -g jupytex
# set timezone
RUN apt update && apt upgrade -y && apt install -y tzdata
ENV TZ=Asia/Tokyo
# install general app
RUN apt update && apt install -y \
    wget \
    unzip \
    tar
RUN apt update && apt install -y python3-pip
USER ${UID}
RUN pip3 install --upgrade pip setuptools && \
    pip3 install --no-cache-dir \
    pygments \
    black \
    flake8 \
    jupyterlab \
    jupyterlab_code_formatter \
    jupyterlab-git \
    lckr-jupyterlab-variableinspector \
    jupyterlab_widgets \
    ipykernel \
    ipywidgets \
    import-ipynb \
    jupyter-contrib-nbextensions \
    jupyter-nbextensions-configurator


FROM ubuntu:22.04 as latex-installer
# set timezone
RUN apt update && apt upgrade -y && apt install -y tzdata
ENV TZ=Asia/Tokyo
# install general app
RUN apt update && apt install -y \
    wget \
    unzip \
    tar
# install LaTeX
ENV PATH /usr/local/bin/texlive:$PATH
WORKDIR /install-tl-unx
RUN apt update && apt install -y perl
COPY ./texlive.profile ./
RUN wget -nv https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
RUN tar -xzf ./install-tl-unx.tar.gz --strip-components=1
RUN ./install-tl --profile=texlive.profile
RUN ln -sf /usr/local/texlive/*/bin/* /usr/local/bin/texlive
RUN apt update && apt install -y libfontconfig1:amd64
RUN tlmgr install \
    collection-fontsrecommended \
    collection-langjapanese \
    collection-latexextra \
    latexmk
ARG TEXMFLOCAL=/usr/local/texlive/texmf-local/tex/latex
WORKDIR /workspace
RUN wget http://captain.kanpaku.jp/LaTeX/jlisting.zip \
    && unzip jlisting.zip \
    && mkdir -p ${TEXMFLOCAL}/listings \
    && cp jlisting/jlisting.sty ${TEXMFLOCAL}/listings
RUN wget http://mirrors.ctan.org/macros/latex/contrib/algorithms.zip \
    && unzip algorithms.zip \
    && cd algorithms \
    && latex algorithms.ins \
    && mkdir -p ${TEXMFLOCAL}/algorithms \
    && cp *.sty ${TEXMFLOCAL}/algorithms
RUN wget http://mirrors.ctan.org/macros/latex/contrib/algorithmicx.zip \
    && unzip algorithmicx.zip \
    && mkdir -p ${TEXMFLOCAL}/algorithmicx \
    && cp algorithmicx/*.sty ${TEXMFLOCAL}/algorithmicx


FROM ubuntu:22.04 as ubuntu-runner
# setting user
ARG UID=1000
RUN groupadd jupytex && useradd -m -u ${UID} jupytex -g jupytex
# set timezone
RUN apt update && apt upgrade -y && apt install -y tzdata
ENV TZ=Asia/Tokyo
# install general app
RUN apt update && apt install -y \
    nano \
    git
COPY --from=latex-installer --chown=jupytex:jupytex /usr/local/texlive /usr/local/texlive
RUN ln -sf /usr/local/texlive/*/bin/* /usr/local/bin/texlive
RUN apt update && apt install -y python3-pip python-is-python3 python3-distutils
RUN mkdir /home/jupytex/.local
COPY --from=python-installer --chown=jupytex:jupytex /home/jupytex/.local /home/jupytex/.local
COPY --from=node-installer --chown=jupytex:jupytex /usr/local/bin/ /usr/local/bin/
COPY --from=node-installer --chown=jupytex:jupytex /usr/local/lib/node_modules /usr/local/lib/node_modules
ENV HOME /home/jupytex
ENV PATH $HOME/.local/bin:$PATH
RUN jupyter labextension install \
    @ryantam626/jupyterlab_code_formatter \
    @jupyterlab/toc && \
    jupyter serverextension enable --py jupyterlab_code_formatter && \
    jupyter contrib nbextension install && \
    jupyter nbextensions_configurator enable
# install Pandoc
RUN apt update && apt install -y pandoc

# make workspace
USER ${UID}
RUN mkdir -m 777 -p $HOME/workspace
RUN mkdir -m 777 -p $HOME/workspace/share
WORKDIR $HOME/workspace
RUN pip3 install --upgrade pip setuptools
RUN pip3 freeze > requirements.txt
RUN git config --global --add safe.directory /home/jupytex/workspace
RUN git config --global init.defaultBranch main