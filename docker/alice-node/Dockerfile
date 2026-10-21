FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY alice_general.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 7781

ENV ALICE_ROLE=GENERAL
ENV ALICE_PORT=7781
ENV RPC_URL=http://host.docker.internal:8546
ENV CHAIN_ID=0
ENV OLLAMA_URL=http://host.docker.internal:11434
ENV OLLAMA_MODEL=mistral

ENTRYPOINT ["./entrypoint.sh"]
