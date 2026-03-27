FROM rocker/tidyverse:4.4.0
LABEL description="FragPipe proteomics pipeline container for CWL workflows"

WORKDIR /rocker-build

# Update and install all dependencies in one layer
RUN apt-get -y update --fix-missing \
    && apt-get -y upgrade \
    && apt-get -y install --no-install-recommends \
        ca-certificates \
        gnupg \
        curl \
        wget \
        git \
        unzip \
        gzip \
        gawk \
        tar \
        fuse \
        man-db \
        openjdk-17-jdk \
        dotnet-runtime-6.0 \
        build-essential \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libncursesw5-dev \
        xz-utils \
        tk-dev \
        libxml2-dev \
        libxmlsec1-dev \
        libffi-dev \
        liblzma-dev \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install CAVATICA SBFS
RUN curl https://igor.sbgenomics.com/downloads/sbfs/install.sh -sSf | sh

# Install Mono
RUN gpg --homedir /tmp --no-default-keyring \
        --keyring /usr/share/keyrings/mono-official-archive-keyring.gpg \
        --keyserver hkp://keyserver.ubuntu.com:80 \
        --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF \
    && echo "deb [signed-by=/usr/share/keyrings/mono-official-archive-keyring.gpg] https://download.mono-project.com/repo/ubuntu stable-focal main" \
        | tee /etc/apt/sources.list.d/mono-official-stable.list \
    && apt-get -y update \
    && apt-get -y install --no-install-recommends mono-devel \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.11
RUN cd /usr/src \
    && wget https://www.python.org/ftp/python/3.11.0/Python-3.11.0.tgz \
    && tar xzf Python-3.11.0.tgz \
    && cd Python-3.11.0 \
    && ./configure --enable-optimizations \
    && make altinstall \
    && cd /usr/src \
    && rm -rf Python-3.11.0.tgz Python-3.11.0

# Setup the default python commands to use Python 3.11
RUN ln -s /usr/local/bin/python3.11 /usr/local/bin/python3 && \
    ln -s /usr/local/bin/python3.11 /usr/local/bin/python
RUN python3 -m pip install --upgrade pip
RUN pip install --no-cache-dir \
    "numpy<2" \
    "pandas<2" \
    "scikit-learn<1.6" \
    "lxml" \
    "easypqp==0.1.55"

# Create FragPipe directory structure
RUN mkdir -p /fragpipe_bin/tools /fragpipe_bin/tmp /fragpipe_bin/refs \
    && chmod 777 /fragpipe_bin /fragpipe_bin/tools /fragpipe_bin/tmp /fragpipe_bin/refs

WORKDIR /fragpipe_bin

# Download and install FragPipe 22.0
RUN wget https://github.com/Nesvilab/FragPipe/releases/download/22.0/FragPipe-22.0.zip -P fragPipe-22.0 \
    && unzip fragPipe-22.0/FragPipe-22.0.zip -d fragPipe-22.0 \
    && chmod -R 777 /fragpipe_bin

# Set environment variables
ENV JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
RUN export JAVA_HOME
ENV FRAGPIPE_BIN="/fragpipe_bin/fragPipe-22.0/fragpipe/bin"
ENV FRAGPIPE_TOOLS="/fragpipe_bin/fragPipe-22.0/fragpipe/tools"
ENV PATH="${FRAGPIPE_BIN}/bin:${FRAGPIPE_TOOLS}/Philosopher:${PATH}"

# Copy required JAR files
COPY tools/MSFragger-4.1.jar ${FRAGPIPE_TOOLS}/MSFragger-4.1.jar 
COPY tools/diaTracer-1.1.5.jar ${FRAGPIPE_TOOLS}/diaTracer-1.1.5.jar 
COPY tools/IonQuant-1.10.27.jar ${FRAGPIPE_TOOLS}/IonQuant-1.10.27.jar

# Copy workflow scripts
COPY scripts/  /opt/scripts/
RUN chmod -R +rx /opt/scripts/ && chown -R 1000:1000 /opt/scripts/