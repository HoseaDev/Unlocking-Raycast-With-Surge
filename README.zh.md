# Raycast AI 代理

这是一个简单的 [Raycast AI](https://raycast.com/)API 代理。它允许您在不订阅的情况下使用 [Raycast AI](https://raycast.com/ai)
应用。它是一个简单的代理，将 raycast 的请求转换格式转发到 OpenAI 的 API，响应后再实时转换格式返回。

[English](README.md) | [中文](README.zh.md)

## 使用方法

### Docker 快速启动

```bash
docker run --name Raycast \
    -e OPENAI_API_KEY=sk-xxxx \
    -e OPENAI_BASE_URL=https://api.openai.com/v1/ \
    -p 12443:80 -e LOG_LEVEL=INFO -d arthals/raycast-backend:latest
```

随后，这个代理会在 `12443` 端口启动代理，为了使用此代理，你还需要参照 https://arthals.ink/posts/coding/unlocking-raycast-with-surge 设置 Surge MiTM 与服务器 Nginx 配置以支持流式传输。

整体的配置思路如下：

Raycast - Surge MiTM 覆写请求 URL - 云服务器 - Nginx 反向代理 - Docker 后端。

其中，证书直接通过 1Panel 的 Nginx（Openresty）搞定就行。与 Surge 和服务器 Docker 均无关。

本镜像只支持服务器使用，本地使用需要能自行签发 SSL 证书。若本地使用建议参照原仓库操作。
