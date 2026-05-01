# HMM Grafana — MDP & ops dashboards

Docker Compose runs **Prometheus** + **Grafana** locally. Market-data dashboards scrape metrics exposed by `hmm-mdp` on AWS through an **SSH tunnel** — Prometheus pulls HTTP `/metrics` endpoints (portsforwarded to your laptop). Grafana does **not** open a raw WebSocket to the EC2 box; the tunnel carries the same telemetry Grafana reads indirectly via Prometheus.

## Quick start

1. **On AWS**, run your HMM stack so each service binds metrics on loopback (defaults):

   | Service        | Remote port |
   | -------------- | ----------- |
   | mdp            | 9101        |
   | pdp            | 9102        |
   | alpha_engine   | 9103        |
   | order_manager  | 9104        |
   | order_executor | 9105        |

   Override with `HMM_METRICS_PORT` per process if needed; adjust `scripts/tunnel-aws-metrics.sh` + `prometheus/prometheus.yml` local ports to match.

2. **On your laptop**, open the multiplex tunnel (leave this running):

   ```bash
   export AWS_SSH_HOST=ec2-xxx.compute.amazonaws.com   # or elastic IP
   # Optional:
   # export AWS_SSH_USER=ec2-user
   # export AWS_SSH_KEY=~/.ssh/your-key.pem
   ./scripts/tunnel-aws-metrics.sh
   ```

3. **Start the stack** (another terminal):

   ```bash
   docker compose up -d
   ```

4. Open **Grafana** at [http://127.0.0.1:3000](http://127.0.0.1:3000) (`admin` / `admin` by default).

5. Dashboards:

   - **MDP (HMM)** — feed health / publish rates (`mdp.json`).
   - **HMM Ops — Orders & Quoting** — open orders by coin, quote-intent rates, OM/OE throughput, reference bid/ask snapshots (`ops_quoting.json`).

Prometheus UI: [http://127.0.0.1:9090](http://127.0.0.1:9090).

### Reload Prometheus config after editing `prometheus.yml`

```bash
curl -X POST http://127.0.0.1:9090/-/reload
```

(or `docker compose restart prometheus`).

---

## Numbers / “6 sig figs”

Grafana **decimal places** are set to **6** on relevant panels (prices, sizes, rates use sensible units). True significant-figure formatting is not built into Prometheus/Grafana; if you need strict sig figs, add a recording rule or transform — this repo uses fixed decimals as the practical analogue.

---

## Per-coin open orders

Requires **`order_manager`** built from a revision that exports `hmm_om_open_orders_by_coin` (periodic gauge). Older binaries still show aggregate `hmm_om_open_orders`.

---

## Minimal-intervention automation

### macOS / Linux: launch tunnel at login

Create `~/.config/systemd/user/hmm-metrics-tunnel.service` (Linux) or use **launchd** / **Task Scheduler** on Windows with the same command line.

Example **systemd user unit**:

```ini
[Unit]
Description=SSH tunnel for HMM Prometheus scrapes
After=network-online.target

[Service]
Type=simple
Environment=AWS_SSH_HOST=your-instance.amazonaws.com
ExecStart=%h/src/hmm-mdp-grafana/scripts/tunnel-aws-metrics.sh
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

Then: `systemctl --user enable --now hmm-metrics-tunnel.service`

Use **SSH config** to avoid env vars:

```
Host hmm-aws
  HostName ec2-xxx.amazonaws.com
  User ec2-user
  IdentityFile ~/.ssh/key.pem
  LocalForward 19101 127.0.0.1:9101
  LocalForward 19102 127.0.0.1:9102
  LocalForward 19103 127.0.0.1:9103
  LocalForward 19104 127.0.0.1:9104
  LocalForward 19105 127.0.0.1:9105
  ServerAliveInterval 30
```

Then `ExecStart=/usr/bin/ssh -N hmm-aws`.

### Optional: Prometheus on EC2

If you prefer **no laptop tunnel**, run Prometheus **on the same VPC** as the trading host and scrape `private-ip:9101–9105` over security-group rules — push this repo’s `prometheus.yml` targets to those IPs. Grafana Cloud / remote_write is another option.

---

## Changing local forward ports

Edit **both** `prometheus/prometheus.yml` (`host.docker.internal:PORT`) and `scripts/tunnel-aws-metrics.sh` (`-L PORT:127.0.0.1:REMOTE`).

---

## License / upstream

Dashboards are provisioned as JSON under `grafana/dashboards/`. Clone upstream: `https://github.com/williamtseng323/hmm-mdp-grafana`.
