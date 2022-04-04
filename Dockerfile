FROM ubuntu:20.04

ENV PYTHON_VERSION 3.9.11

ENV NODE_VERSION 17

ENV PATH /usr/local/texlive/2021/bin/x86_64-linux:$PATH

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

# install Node
RUN curl -sL https://deb.nodesource.com/setup_$NODE_VERSION.x | bash -
RUN apt install -y nodejs

# install Python
ENV PYTHON_ROOT /usr
ENV PATH $PYTHON_ROOT/bin:$PATH
ENV PYENV_ROOT /usr/.pyenv
RUN apt purge -y --auto-remove python3.8
RUN apt update && apt install -y \
  build-essential \
  libssl-dev \
  zlib1g-dev \
  libbz2-dev \
  libreadline-dev \
  libsqlite3-dev \
  llvm \
  libncurses5-dev \
  libncursesw5-dev \
  xz-utils \
  tk-dev \
  libffi-dev \
  liblzma-dev && \
  git clone https://github.com/pyenv/pyenv.git $PYENV_ROOT && \
  $PYENV_ROOT/plugins/python-build/install.sh && \
  usr/local/bin/python-build -v $PYTHON_VERSION $PYTHON_ROOT && \
  rm -rf $PYENV_ROOT

# install LaTeX
RUN apt update && apt install -y \
  perl && \
  mkdir /tmp/install-tl-unx && \
  curl -L http://ftp.yz.yamagata-u.ac.jp/pub/CTAN/systems/texlive/Source/install-tl-unx.tar.gz | \
  tar -xz -C /tmp/install-tl-unx --strip-components=1 && \
  printf "%s\n" \
  "selected_scheme scheme-basic" \
  "tlpdbopt_install_docfiles 0" \
  "tlpdbopt_install_srcfiles 0" \
  > /tmp/install-tl-unx/texlive.profile && \
  /tmp/install-tl-unx/install-tl \
  --profile=/tmp/install-tl-unx/texlive.profile && \
  tlmgr install \
  collection-latexextra \
  collection-fontsrecommended \
  collection-langjapanese \
  latexmk && \
  tlmgr update --self --all && \
  apt clean && \
  rm -rf /var/lib/apt/lists/*

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
ENV HOME /home/jupytex
ENV PATH $HOME/.local/bin:$PATH
RUN echo $PATH

RUN pip3 install --upgrade pip setuptools && \
  pip3 install --no-cache-dir \
  poetry \
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

WORKDIR $HOME
RUN poetry config virtualenvs.in-project true
RUN poetry new --src project-x

WORKDIR $HOME/project-x
RUN poetry add -D ipykernel
RUN poetry add numpy pandas matplotlib scikit-learn
RUN poetry run ipython kernel install --user --name=project-x --display-name=project-x

RUN apt update && apt install -y pandoc
RUN npm install -global textlint textlint-rule-preset-ja-technical-writing textlint-filter-rule-comments textlint-filter-rule-whitelist
CMD ["bash"]
