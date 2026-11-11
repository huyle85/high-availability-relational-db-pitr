FROM postgres:16-bookworm
 
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-psycopg2 pgbackrest \
      curl iputils-ping procps gettext-base openssl ca-certificates \
 && python3 -m venv --system-site-packages /opt/patroni \
 && /opt/patroni/bin/pip install --no-cache-dir "patroni[etcd3]" \
 && rm -rf /var/lib/apt/lists/*
 
ENV PATH="/opt/patroni/bin:${PATH}"
 
RUN mkdir -p /var/log/pgbackrest /var/spool/pgbackrest /etc/pgbackrest /etc/patroni /certs \
 && chown -R postgres:postgres /var/log/pgbackrest /var/spool/pgbackrest /etc/pgbackrest /etc/patroni
COPY --chown=postgres:postgres entrypoint.sh /entrypoint.sh
COPY --chown=postgres:postgres patroni.yml.tpl /etc/patroni/patroni.yml.tpl
COPY --chown=postgres:postgres pgbackrest.conf /etc/pgbackrest/pgbackrest.conf
 
RUN chmod +x /entrypoint.sh
 
USER postgres
ENTRYPOINT ["/entrypoint.sh"]
