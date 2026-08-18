FROM public.ecr.aws/docker/library/python:3.13-alpine
RUN pip install --no-cache-dir boto3
COPY worker.py /worker.py
USER 65532:65532
ENTRYPOINT ["python", "-u", "/worker.py"]

