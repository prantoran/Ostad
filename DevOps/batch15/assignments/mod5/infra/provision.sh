#!/usr/bin/env bash
# Provisions the AWS side of ShopNest with the AWS CLI (default VPC, 2 EC2 instances).
#   app server (public)  : nginx + Node backend, SSH + HTTP open
#   db server            : PostgreSQL; 5432 and 22 reachable ONLY from the app server's security group
# Secrets/keys are written to infra/.out/ (git-ignored) and never committed.
#
# Usage: infra/provision.sh <step>      steps: network | instances | bootstrap | teardown
set -euo pipefail
REGION="${AWS_REGION:-us-east-1}"
export AWS_REGION="$REGION" AWS_PAGER=""
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/infra/.out"; mkdir -p "$OUT"; chmod 700 "$OUT"
NAME=shopnest
KEY="$OUT/$NAME-key.pem"
my_ip() { curl -fsS https://checkip.amazonaws.com; }

step_network() {
  VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
  echo "VPC=$VPC" > "$OUT/ids.env"

  APP_SG=$(aws ec2 create-security-group --group-name $NAME-app --description "ShopNest app server" --vpc-id "$VPC" --query GroupId --output text)
  DB_SG=$(aws ec2 create-security-group --group-name $NAME-db --description "ShopNest database" --vpc-id "$VPC" --query GroupId --output text)
  echo "APP_SG=$APP_SG" >> "$OUT/ids.env"; echo "DB_SG=$DB_SG" >> "$OUT/ids.env"

  # App: HTTP (prod 80, staging 8080) from anywhere; SSH open (GitHub-hosted runners use dynamic IPs).
  for p in 80 8080 22; do
    aws ec2 authorize-security-group-ingress --group-id "$APP_SG" --protocol tcp --port $p --cidr 0.0.0.0/0 >/dev/null
  done
  # DB: only from the app security group. No CIDR rule => not reachable from the internet.
  for p in 5432 22; do
    aws ec2 authorize-security-group-ingress --group-id "$DB_SG" --protocol tcp --port $p --source-group "$APP_SG" >/dev/null
  done

  aws ec2 create-key-pair --key-name $NAME-key --query KeyMaterial --output text > "$KEY"
  chmod 400 "$KEY"
  echo "network done"; cat "$OUT/ids.env"
}

step_instances() {
  . "$OUT/ids.env"
  AMI=$(aws ssm get-parameter --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id --query Parameter.Value --output text)
  SUBNET=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC" Name=default-for-az,Values=true --query 'Subnets[0].SubnetId' --output text)

  cat > "$OUT/app-userdata.sh" <<'EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y nginx curl ca-certificates gnupg
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
systemctl enable --now nginx
touch /var/lib/cloud/instance/shopnest-ready
EOF
  cat > "$OUT/db-userdata.sh" <<'EOF'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y postgresql
PGV=$(ls /etc/postgresql)
sed -i "s/^#listen_addresses.*/listen_addresses = '*'/" /etc/postgresql/$PGV/main/postgresql.conf
echo "host all all 172.31.0.0/16 scram-sha-256" >> /etc/postgresql/$PGV/main/pg_hba.conf
systemctl restart postgresql
touch /var/lib/cloud/instance/shopnest-ready
EOF

  run() { # name sg userdata
    aws ec2 run-instances --image-id "$AMI" --instance-type t3.micro --key-name $NAME-key \
      --security-group-ids "$2" --subnet-id "$SUBNET" --associate-public-ip-address \
      --user-data "file://$3" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$1},{Key=Project,Value=shopnest}]" \
      --query 'Instances[0].InstanceId' --output text
  }
  APP_ID=$(run $NAME-app "$APP_SG" "$OUT/app-userdata.sh")
  DB_ID=$(run $NAME-db "$DB_SG" "$OUT/db-userdata.sh")
  echo "APP_ID=$APP_ID" >> "$OUT/ids.env"; echo "DB_ID=$DB_ID" >> "$OUT/ids.env"
  aws ec2 wait instance-running --instance-ids "$APP_ID" "$DB_ID"

  APP_IP=$(aws ec2 describe-instances --instance-ids "$APP_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  APP_PRIV=$(aws ec2 describe-instances --instance-ids "$APP_ID" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
  DB_PRIV=$(aws ec2 describe-instances --instance-ids "$DB_ID" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
  DB_PUB=$(aws ec2 describe-instances --instance-ids "$DB_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  { echo "APP_IP=$APP_IP"; echo "APP_PRIV=$APP_PRIV"; echo "DB_PRIV=$DB_PRIV"; echo "DB_PUB=$DB_PUB"; } >> "$OUT/ids.env"
  echo "instances running; wait ~3 min for cloud-init, then run: infra/provision.sh bootstrap"
}

step_bootstrap() {
  . "$OUT/ids.env"
  SSH="ssh -i $KEY -o StrictHostKeyChecking=accept-new"
  until $SSH -o ConnectTimeout=5 ubuntu@"$APP_IP" 'test -f /var/lib/cloud/instance/shopnest-ready'; do echo "waiting for app server..."; sleep 10; done
  scp -i "$KEY" -o StrictHostKeyChecking=accept-new "$ROOT"/deploy/{deploy.sh,run-backend.sh,bootstrap-app.sh,shopnest@.service,nginx.conf.tpl} ubuntu@"$APP_IP":/tmp/
  $SSH ubuntu@"$APP_IP" 'sudo bash /tmp/bootstrap-app.sh'

  # Reach the DB through the app server (jump host) because the DB firewall only admits the app SG.
  PROXY="ssh -i $KEY -o StrictHostKeyChecking=accept-new -J ubuntu@$APP_IP"
  scp -i "$KEY" "$KEY" ubuntu@"$APP_IP":/tmp/k.pem >/dev/null 2>&1 || true   # not needed with -J; harmless
  until $PROXY -o ConnectTimeout=5 ubuntu@"$DB_PRIV" 'test -f /var/lib/cloud/instance/shopnest-ready'; do echo "waiting for db server..."; sleep 10; done

  for E in staging production; do
    PW=$(openssl rand -hex 24); echo "DB_PASSWORD_$E=$PW" >> "$OUT/secrets.env"
    $PROXY ubuntu@"$DB_PRIV" "sudo -u postgres psql -v ON_ERROR_STOP=1" <<SQL
CREATE ROLE shopnest_$E LOGIN PASSWORD '$PW';
CREATE DATABASE shopnest_$E OWNER shopnest_$E;
SQL
  done
  chmod 600 "$OUT/secrets.env"
  ssh-keyscan -H "$APP_IP" > "$OUT/known_hosts" 2>/dev/null
  echo "bootstrap done. Values for GitHub are in $OUT (ids.env, secrets.env, known_hosts, $NAME-key.pem)"
}

step_teardown() {
  . "$OUT/ids.env"
  aws ec2 terminate-instances --instance-ids "$APP_ID" "$DB_ID" >/dev/null
  aws ec2 wait instance-terminated --instance-ids "$APP_ID" "$DB_ID"
  aws ec2 delete-security-group --group-id "$DB_SG"
  aws ec2 delete-security-group --group-id "$APP_SG"
  aws ec2 delete-key-pair --key-name $NAME-key
  echo "torn down"
}

"step_${1:?usage: provision.sh network|instances|bootstrap|teardown}"
