FROM gcr.io/distroless/static-debian13:nonroot
COPY --chmod=0555 assets/book /app/book
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/app/book"]
