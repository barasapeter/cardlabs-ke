FROM python:3.13.2-slim

WORKDIR /app

COPY . /app

RUN pip install -r requirements.txt