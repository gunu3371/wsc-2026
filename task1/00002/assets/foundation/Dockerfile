FROM public.ecr.aws/docker/library/alpine:3.21
RUN addgroup -S app && adduser -S -G app app
COPY --chown=app:app assets/book /app/book
USER app
EXPOSE 8080
ENTRYPOINT ["/app/book"]
