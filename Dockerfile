FROM fcyucn/fragpipe:latest
LABEL description="Thin FragPipe v24 wrapper for CWL workflows (uses public fcyucn/fragpipe image)"

WORKDIR /opt

# Install Python helpers used by repo scripts.
RUN python3 -m pip install --upgrade pip \
    && pip uninstall -y easypqp --break-system-packages || true \
    && pip install --break-system-packages git+https://github.com/grosenberger/easypqp.git@master \
    && pip install --break-system-packages lxml pandas

# Install gawk (mawk in this base image lacks 3-arg match support)
RUN apt-get update && apt-get install -y --no-install-recommends gawk \
    && ln -sf /usr/bin/gawk /usr/bin/awk \
    && rm -rf /var/lib/apt/lists/*

# Restore core FragPipe jars that are missing from the current upstream base image.
COPY tools/MSFragger-4.4.1.jar /fragpipe_bin/fragpipe-24.0/fragpipe-24.0/tools/MSFragger-4.4.1.jar
COPY tools/IonQuant-1.11.20.jar /fragpipe_bin/fragpipe-24.0/fragpipe-24.0/tools/IonQuant-1.11.20.jar
COPY tools/diaTracer-2.2.1.jar /fragpipe_bin/fragpipe-24.0/fragpipe-24.0/tools/diaTracer-2.2.1.jar

# Keep script ownership and execute permissions aligned with existing CWL usage.
COPY scripts/ /opt/scripts/
RUN chmod -R +rx /opt/scripts/ && chown -R 1000:1000 /opt/scripts/
