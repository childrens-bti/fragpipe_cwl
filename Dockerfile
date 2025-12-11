FROM ubuntu:22.04
LABEL description="FragPipe proteomics pipeline container for CWL workflows"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

WORKDIR /build

# Update and install base dependencies
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
        vim \
        tar \
        fuse \
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

# Install CAVATICA SBFS (optional - for mounting Seven Bridges filesystems)
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

# Setup Python symlinks and install packages
RUN ln -sf /usr/local/bin/python3.11 /usr/local/bin/python3 \
    && ln -sf /usr/local/bin/python3.11 /usr/local/bin/python \
    && python3 -m pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir \
        git+https://github.com/Nesvilab/easypqp.git@master \
        lxml

# Create FragPipe directory structure
RUN mkdir -p /fragpipe_bin/tools /fragpipe_bin/tmp /fragpipe_bin/refs \
    && chmod 777 /fragpipe_bin /fragpipe_bin/tools /fragpipe_bin/tmp /fragpipe_bin/refs

WORKDIR /fragpipe_bin

# Download and install FragPipe 23.1
RUN wget https://github.com/Nesvilab/FragPipe/releases/download/23.1/FragPipe-23.1-linux.zip \
    && unzip FragPipe-23.1-linux.zip \
    && rm FragPipe-23.1-linux.zip \
    && chmod -R 777 /fragpipe_bin

# Set environment variables
ENV JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
RUN export JAVA_HOME
ENV FRAGPIPE_BIN="/fragpipe_bin/fragpipe-23.1"
ENV FRAGPIPE_TOOLS="/fragpipe_bin/fragpipe-23.1/tools"
ENV PATH="${FRAGPIPE_BIN}/bin:${FRAGPIPE_TOOLS}/Philosopher:${PATH}"

# Copy required JAR files (uncomment and provide at build time)
COPY MSFragger-4.3.jar ${FRAGPIPE_TOOLS}/MSFragger-4.3.jar 
COPY diaTracer-1.3.3.jar ${FRAGPIPE_TOOLS}/diaTracer-1.3.3.jar
COPY IonQuant-1.11.11.jar ${FRAGPIPE_TOOLS}/IonQuant-1.11.11.jar

# Copy workflow scripts
COPY scripts/ /scripts/
RUN chmod -R +rx /scripts/ && chown -R 1000:1000 /scripts/
