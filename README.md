# Unlocking-Raycast-With-Surge

利用 Surge 的 MiTM 功能拦截请求，并利用 Docker 服务模拟后端操作，从而实现 Raycast 的激活。

Docker 服务是一个简单的 [Raycast AI](https://raycast.com/)API 代理。它允许您在不订阅的情况下使用 [Raycast AI](https://raycast.com/ai)
应用。它是一个简单的代理，将 raycast 的请求转换格式转发到 OpenAI 的 API，响应后再实时转换格式返回。

Docker 服务修改自 [yufeikang/raycast_api_proxy](https://github.com/yufeikang/raycast_api_proxy)。由于我在迁移的时候出现了问题，新建此仓库后失去了 `fork` 的属性。但保留了 `.git` 贡献历史。

整体的配置思路如下：

Raycast - Surge MiTM 覆写请求 URL - 云服务器 - Nginx 反向代理 - Docker 后端。

## 使用方法

### 在服务端启动 Docker

此 Docker 镜像修改自 [yufeikang/raycast_api_proxy](https://github.com/yufeikang/raycast_api_proxy)，修复了一些迁移到服务器上会导致的问题。

```bash
docker run --name Raycast \
    -e OPENAI_API_KEY=sk-xxxx \
    -e OPENAI_BASE_URL=https://api.openai.com/v1/ \
    -p 12443:80 -e LOG_LEVEL=INFO -d arthals/raycast-backend:latest
```

随后，这个代理会在 `12443` 端口启动代理，为了使用此代理，你还需要参照 https://arthals.ink/posts/coding/unlocking-raycast-with-surge 或按照下文设置 Surge MiTM 与服务器 Nginx 配置以支持流式传输。

SSL 证书直接通过 1Panel 的 Nginx（Openresty）搞定就行。与 Surge 和服务器 Docker 均无关。

本镜像只支持服务器使用，本地使用需要能自行签发 SSL 证书。若本地使用建议参照原仓库操作。

### Nginx 服务端配置

Nginx 反向代理配置如下：

```nginx
location ^~ / {
    proxy_pass http://127.0.0.1:12443;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header REMOTE-HOST $remote_addr;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_http_version 1.1;
    add_header Cache-Control no-cache;
    proxy_cache off;  # 关闭缓存
    proxy_buffering off;  # 关闭代理缓冲
    chunked_transfer_encoding on;  # 开启分块传输编码
    tcp_nopush on;  # 开启TCP NOPUSH选项，禁止Nagle算法
    tcp_nodelay on;  # 开启TCP NODELAY选项，禁止延迟ACK算法
    keepalive_timeout 300;  # 设定keep-alive超时时间为65秒
}
```

### Surge MiTM 配置与激活脚本

本质是劫持 Raycast 的请求，将请求转发到服务器上。配置如下：

```conf
# surge.conf
[MITM]
skip-server-cert-verify = true
h2 = true
hostname = *.raycast.com
ca-passphrase = ...
ca-p12 = MIIKP...

[Script]
raycast-activate-backend.raycast.com = type=http-request,pattern=^https://backend.raycast.com,max-size=0,debug=1,script-path=activator.js
```

请注意，你需要将 `ca-passphrase` 与 `ca-p12` 替换为你自己的 Surge CA 密码与证书。

其中用到的 `activator.js` 脚本修改自 [wibus-wee/activation-script](https://github.com/wibus-wee/activation-script/)，你需要自行修改其中的 `https://custome-backend.self.com` 为你的服务器地址。

请将 `activator.js` 放置在 Surge 配置文件夹下。

Activator.js 内容如下（亦可在本仓库找到）：

```js
'use strict';

function transformToString(obj) {
    if (typeof obj === 'object') {
        return JSON.stringify(obj);
    }
    return obj;
}
/**
 * 构建 Surge 响应体
 *
 * @param props 响应体属性
 * @description 该函数将会自动将对象转换为 JSON 字符串，因此你可以直接传入对象
 */
function buildResponse(props) {
    if (props.body) {
        props.body = transformToString(props.body);
    }
    // console.log(props.body);
    $done({
        ...props,
    });
}
/**
 * 发送通知
 *
 * @param title 标题
 * @param subtitle 副标题
 * @param body 内容
 * @description 该函数将会自动将对象转换为 JSON 字符串，因此你可以直接传入对象
 */
function sendNotification(title, subtitle, body) {
    title = transformToString(title);
    subtitle = transformToString(subtitle);
    body = transformToString(body);
    $notification.post(title, subtitle, body);
}
const methods = ['get', 'put', 'delete', 'head', 'options', 'patch', 'post'];
/**
 * 发送请求
 * @param props 请求参数
 * @param callback 回调函数
 */
const httpClient = {};
for (let method of methods) {
    // @ts-ignore
    httpClient[method] = (props, callback) => {
        $httpClient[method](props, callback);
    };
}

/**
 * @url https://backend.raycast.com/api/
 */
function raycastActivate() {
    $done({
        url: $request.url.replace('https://backend.raycast.com', 'https://custome-backend.self.com'),
        headers: $request.headers,
        body: $request.body,
    });
}

const activator = {
    raycast: {
        base: 'https://backend.raycast.com/api/',
        activate: [
            {
                base: '*',
                func: raycastActivate,
            },
        ],
    },
};

const url = $request.url;
/**
 * Determine whether the URL matches the base
 */
function isMatchBase(url, base) {
    if (Array.isArray(base)) {
        for (let item of base) {
            if (url.includes(item)) {
                return true;
            }
        }
        return false;
    }
    return url.includes(base);
}
/**
 * Automatic execution of the corresponding function according to the URL
 */
function launch() {
    for (let module in activator) {
        if (isMatchBase(url, activator[module].base)) {
            for (let key in activator[module]) {
                if (key === 'base') continue;
                if (Array.isArray(activator[module][key])) {
                    for (let custom of activator[module][key]) {
                        // 检查 custom.base 是否为通配符 '*'，如果是，则匹配任何以 activator[module].base 开头的URL
                        if (custom.base === '*' && url.startsWith(activator[module].base)) {
                            return custom.func();
                        }
                        // 否则，检查精确匹配
                        else if (url === `${activator[module].base}/${custom.base}`) {
                            return custom.func();
                        }
                    }
                    continue;
                }
                if (typeof activator[module][key] === 'object') {
                    if (url === `${activator[module].base}/${activator[module][key].base}`) {
                        return activator[module][key].func();
                    }
                } else if (!url.includes(`${activator[module].base}/${key}`)) {
                    return;
                }
                if (typeof activator[module][key] === 'function') {
                    return activator[module][key]();
                }
            }
        }
    }
    console.log(`[activator] ${url} is not matched`);
    returnDefaultResponse();
    $done();
    return;
}
function returnDefaultResponse() {
    console.log(`[activator] returnDefaultResponse: ${url} - ${$request.method.toLowerCase()}`);
    // @ts-expect-error
    httpClient[$request.method.toLowerCase()](
        {
            url: $request.url,
            headers: $request.headers,
        },
        (err, response, _data) => {
            if (!_data) {
                console.log('returnDefaultResponse: _data is null', err);
                buildResponse({
                    status: 500,
                    body: {},
                });
            }
            buildResponse({
                status: response.status,
                headers: response.headers,
                body: _data,
            });
        }
    );
}

launch();
```
