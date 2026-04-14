# Access Backend From A Physical Phone

This backend is a FastAPI app. For a real phone to access it, two things matter:

1. The API process must listen on a network-reachable interface, not only `127.0.0.1`.
2. CORS must allow the origin used by your Flutter web build or any browser-based client.

## Option 1: Direct LAN Access

Run the API on all interfaces:

```bash
source venv/bin/activate
export API_HOST=0.0.0.0
export API_PORT=8000
export CORS_ALLOWED_ORIGINS=http://192.168.1.10:3000,http://192.168.1.10:8080
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Replace `192.168.1.10` with your laptop's Wi-Fi IP.

Then in the phone or Flutter app use:

```text
http://192.168.1.10:8000/api/v1
```

## Option 2: Expose Through nginx On The Same Laptop

Keep FastAPI on port `8000`, then put nginx in front on `8080`.

Example config:

```nginx
server {
    listen 8080;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

This same example is available in `nginx/mobile-access.conf.example`.

If nginx is installed on Ubuntu:

```bash
sudo cp nginx/mobile-access.conf.example /etc/nginx/sites-available/erp-mobile
sudo ln -s /etc/nginx/sites-available/erp-mobile /etc/nginx/sites-enabled/erp-mobile
sudo nginx -t
sudo systemctl reload nginx
```

Then access from your phone with:

```text
http://192.168.1.10:8080/api/v1
```

## Flutter Notes

- Android emulator can use `10.0.2.2`, but a real phone cannot.
- A physical phone must use your laptop's real LAN IP, for example `192.168.1.10`.
- Phone and laptop must be on the same Wi-Fi network.
- Your firewall must allow inbound traffic on `8000` or `8080`.

## Quick Check

From your laptop:

```bash
ip addr
curl http://127.0.0.1:8000/docs
curl http://192.168.1.10:8000/docs
curl http://192.168.1.10:8080/docs
```

If direct LAN works, nginx is optional. nginx is only useful if you want one stable public-facing port or later add TLS/auth/routing.
