# Rendered per environment by bootstrap-app.sh: @ENV@, @PORT@
upstream shopnest_@ENV@ {
    include /etc/shopnest/@ENV@/upstream.inc;
    keepalive 16;
}

server {
    listen @PORT@;
    server_name _;

    root /opt/shopnest/@ENV@/current/frontend;
    index index.html;

    location /api/ {
        proxy_pass http://shopnest_@ENV@;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_next_upstream error timeout http_502 http_503;
    }

    location = /health {
        proxy_pass http://shopnest_@ENV@;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }

    location / {
        try_files $uri /index.html;
    }
}
