FROM ubuntu:22.04

ENV NODE_VERSION 16

ENV HOME /home/jupytex

# setting user
ARG UID=1000
RUN groupadd jupytex && useradd -m -u ${UID} jupytex -g jupytex
#USER ${UID}

# set timezone
RUN apt update && apt upgrade -y && apt install -y tzdata
ENV TZ=Asia/Tokyo

# install general app
RUN apt update && apt install -y \
    make \
    curl \
    wget \
    unzip \
    tar \
    nano \
    git

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

# add LaTeX modules
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


# add Python modules
WORKDIR $HOME
RUN apt update && apt install -y python3-pip
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
    ipywidgets \
    import-ipynb \
    jupyter-contrib-nbextensions \
    jupyter-nbextensions-configurator && \
    jupyter labextension install \
    @ryantam626/jupyterlab_code_formatter \
    @jupyterlab/toc && \
    jupyter serverextension enable --py jupyterlab_code_formatter && \
    jupyter contrib nbextension install && \
    jupyter nbextensions_configurator enable

# install Poetry
RUN pip3 install --no-cache-dir  poetry
RUN apt update && apt install -y  python-is-python3 python3-distutils
RUN poetry config virtualenvs.in-project true
RUN poetry new project-x
WORKDIR $HOME/project-x
RUN poetry add -D ipykernel
RUN poetry run ipython kernel install --user --name=project-x --display-name=project-x

# install Pandoc
RUN apt update && apt install -y pandoc

# install Node
RUN curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash -
RUN apt install -y nodejs

# add textlint
RUN npm install -global textlint textlint-rule-preset-ja-technical-writing textlint-filter-rule-comments textlint-filter-rule-whitelist
