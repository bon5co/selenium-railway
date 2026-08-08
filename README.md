# selenium-railway

Railway-tuned [docker-selenium](https://github.com/SeleniumHQ/docker-selenium) images, pinned to
Selenium **4.46.0** (`4.46.0-20260707`). Wrapper images for the Railway marketplace templates.

| Image | Base | Role |
| --- | --- | --- |
| `ghcr.io/bon5co/selenium-standalone-chromium-railway` | `selenium/standalone-chromium` | one-container grid, Chromium |
| `ghcr.io/bon5co/selenium-standalone-firefox-railway` | `selenium/standalone-firefox` | one-container grid, Firefox |
| `ghcr.io/bon5co/selenium-standalone-edge-railway` | `selenium/standalone-edge` | one-container grid, Edge |
| `ghcr.io/bon5co/selenium-hub-railway` | `selenium/hub` | public hub of the multi-node grid |
| `ghcr.io/bon5co/selenium-node-chromium-railway` | `selenium/node-chromium` | private Chromium node |
| `ghcr.io/bon5co/selenium-node-firefox-railway` | `selenium/node-firefox` | private Firefox node |

## What these change

1. **The router requires a password.** A Selenium Grid runs arbitrary code and browses the network
   from inside your project; the stock image ships no authentication, and a Railway deploy puts it
   on a public HTTPS URL. These images enable Grid's built-in router basic auth and **refuse to
   start** with an empty `SE_ROUTER_PASSWORD`.
2. **`$PORT` is honoured.** Railway's HTTP healthcheck dials the injected port, not the domain's
   target port, so a service pinned to 4444 fails its deploy while serving 200 to the world.
3. **Private networking works.** `*.railway.internal` is IPv6-only and the JVM prefers IPv4, so a
   stock node never finds its hub. `-Djava.net.preferIPv6Addresses=true` is set for every role.
4. **Session count is pinned.** `nproc` inside a container reports the host's cores, so Selenium's
   automatic `min(cpus, 8)` sizes itself for the metal and oversubscribes the plan.
5. **`--disable-dev-shm-usage` is baked in.** A container gets 64 MB of `/dev/shm`; upstream's fix
   is `docker run --shm-size=2g`, which a Railway deployer cannot pass.

## Variables

| Variable | Default | Notes |
| --- | --- | --- |
| `SE_ROUTER_USERNAME` | `selenium` | baked in |
| `SE_ROUTER_PASSWORD` | — | **required**, generated per deploy by the template |
| `SE_NODE_MAX_SESSIONS` | `2` | raise with the plan |
| `SE_NODE_SESSION_TIMEOUT` | `300` | seconds |
| `SE_START_VNC` / `SE_START_NO_VNC` | `false` | set both `true` to watch a run; noVNC listens on 7900 with no auth of its own |

Connect a client to `https://selenium:<password>@<your-domain>/wd/hub`.
