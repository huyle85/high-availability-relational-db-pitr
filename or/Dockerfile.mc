FROM cgr.dev/chainguard/minio-client:latest AS mc_bin
FROM alpine:3.19
COPY --from=mc_bin /usr/bin/mc /usr/bin/mc
ENTRYPOINT ["mc"]
