FROM public.ecr.aws/docker/library/alpine:3.21 AS tools
RUN apk add --no-cache build-base
RUN printf '%s\n' '#include <stdlib.h>' '#include <unistd.h>' 'int main(int argc, char **argv) { if (argc != 2) return 2; unsigned int seconds = (unsigned int)strtoul(argv[1], 0, 10); return sleep(seconds) == 0 ? 0 : 1; }' > /tmp/sleep.c \
    && cc -Os -static -s -o /bin/sleep /tmp/sleep.c

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=tools /bin/sleep /bin/sleep
COPY --chmod=0555 assets/book /app/book
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app/book"]
