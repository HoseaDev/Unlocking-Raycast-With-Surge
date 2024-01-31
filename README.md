# Raycast AI Proxy

This is a simple [Raycast AI](https://raycast.com/) API proxy. It allows you to use the [Raycast AI](https://raycast.com/ai) app without a subscription.
It's a simple proxy that forwards requests from Raycast to the OpenAI API, converts the format, and returns the response in real-time.

[English](README.md) | [中文](README.zh.md)

## How to Use

### Quick Start with Docker

```bash
docker run --name Raycast \
    -e OPENAI_API_KEY=sk-xxxx \
    -e OPENAI_BASE_URL=https://api.openai.com/v1/ \
    -p 12443:80 -e LOG_LEVEL=INFO -d arthals/raycast-backend:latest
```

Subsequently, this proxy will start on port `12443` to serve as a proxy. In order to use this proxy, you also need to refer to https://arthals.ink/posts/coding/unlocking-raycast-with-surge for setting up Surge MiTM and server Nginx configuration to support streaming.

The overall configuration idea is as follows:

Raycast - Surge MiTM overrides request URL - Cloud server - Nginx reverse proxy - Backend Docker.

Regarding the certificate, it can be easily handled through 1Panel's Nginx (Openresty). It is unrelated to Surge and server Docker.

This image only supports server usage; if used locally, one needs to be able to issue SSL certificates independently. If using locally, it is recommended to follow the instructions in the original repository.
