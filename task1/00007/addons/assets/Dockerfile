FROM public.ecr.aws/docker/library/python:3.13-slim
RUN pip install --no-cache-dir flask boto3
COPY app.py /app.py
CMD ["python", "/app.py"]
