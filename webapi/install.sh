username=webapiuser

# from root: create user and add user to sudoers
adduser $username
usermod -a -G sudo $username
su - $username


hostname=api.acme.com

# https
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/local/bin/certbot
sudo certbot certonly -a standalone -d $hostname
sudo chmod 0755 /etc/letsencrypt/{live,archive} # https://eff-certbot.readthedocs.io/en/stable/using.html#where-are-my-certificates
sudo ln -s /etc/letsencrypt/live/$hostname/privkey.pem
sudo ln -s /etc/letsencrypt/live/$hostname/fullchain.pem

# nat redirection
sudo systemctl enable nftables.service
sudo systemctl start nftables

sudo nft add table inet nat
sudo nft 'add chain inet nat PREROUTING { type nat hook prerouting priority -100; };'
sudo nft add rule inet nat PREROUTING tcp dport 443 redirect to :8000
sudo nft list ruleset | sudo tee -a /etc/nftables.conf


# uv installation
curl -LsSf https://astral.sh/uv/install.sh | sh

# create a new program or get one
cat > ./pyproject.toml << EOF
[project]
name = "api"
version = "0.0.1"
requires-python = ">=3.13"
dependencies = [
    "fastapi[standard-no-fastapi-cloud-cli]>=0.128.0"
]
EOF

cat > ./main.py << EOF
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def hello():
    return "hello"
EOF


# create and enable service:
servicefile=webapi.service

sudo cat <<EOF | sudo tee /etc/systemd/system/$servicefile
[Unit]
Description=....
After=syslog.target
After=network.target

[Service]
User=$(whoami)
WorkingDirectory=~
ExecStart=/home/$(whoami)/.venv/bin/uvicorn  main:app --host 0.0.0.0 --ssl-keyfile=./privkey.pem --ssl-certfile=./fullchain.pem
Restart=always
TimeoutSec=15
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF


sudo systemctl daemon-reload
sudo systemctl enable $servicefile
sudo systemctl start $servicefile
sudo systemctl status $servicefile
