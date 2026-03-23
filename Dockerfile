FROM fcyucn/fragpipe:latest
LABEL description="Thin FragPipe v24 wrapper for CWL workflows (uses public fcyucn/fragpipe image)"

WORKDIR /opt

# Install Python helpers used by repo scripts.
RUN python3 -m pip install --upgrade pip \
    && pip uninstall -y easypqp --break-system-packages || true \
    && pip install --break-system-packages git+https://github.com/grosenberger/easypqp.git@master \
    && pip install --break-system-packages lxml pandas

# Keep script ownership and execute permissions aligned with existing CWL usage.
COPY scripts/ /opt/scripts/
RUN chmod -R +rx /opt/scripts/ && chown -R 1000:1000 /opt/scripts/
