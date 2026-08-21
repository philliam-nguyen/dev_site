resource "aws_security_group" "proxy" {
  name        = "meal-prep-proxy"
  description = "Proxy instance. No inbound here: CloudFront service-managed group is admitted in cdn.tf, once the VPC origin exists to create it."
  vpc_id      = aws_vpc.this.id
}

# Egress restricts ports, not destinations: security groups filter by CIDR,
# Tailscale warns against pinning its IPs, and the DERP set grows over time.
resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.proxy.id
  description       = "Tailscale control plane and DERP relays, dnf, SSM"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "stun" {
  security_group_id = aws_security_group.proxy.id
  description       = "STUN, to DERP servers"
  ip_protocol       = "udp"
  from_port         = 3478
  to_port           = 3478
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "wireguard" {
  security_group_id = aws_security_group.proxy.id
  description       = "Direct WireGuard, when a direct path exists; DERP over 443 otherwise"
  ip_protocol       = "udp"
  from_port         = 41641
  to_port           = 41641
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "http" {
  security_group_id = aws_security_group.proxy.id
  description       = "Faster Tailscale control-plane connect; optional per their firewall FAQ"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "proxy" {
  name = "meal-prep-proxy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "read_auth_key" {
  name = "read-tailscale-auth-key"
  role = aws_iam_role.proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:GetParameter"
      Resource = "arn:aws:ssm:us-east-1:${data.aws_caller_identity.current.account_id}:parameter/meal-prep/tailscale-auth-key"
    }]
  })
}

resource "aws_iam_instance_profile" "proxy" {
  name = "meal-prep-proxy"
  role = aws_iam_role.proxy.name
}

data "aws_ami" "al2023_arm64" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-arm64"]
  }
}

resource "aws_instance" "proxy" {
  ami                    = data.aws_ami.al2023_arm64.id
  instance_type          = "t4g.nano"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.proxy.id]
  iam_instance_profile   = aws_iam_instance_profile.proxy.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    region        = "us-east-1"
    ssm_param     = "/meal-prep/tailscale-auth-key"
    demo_upstream = var.demo_upstream
  })

  # cloud-init runs user data once per instance, not per boot. Without this
  # flag a script change stop/starts the same instance and never re-runs,
  # leaving the config silently stale.
  user_data_replace_on_change = true

  # Pinned at first apply; a new monthly AMI must not read as a surprise
  # instance replacement in an unrelated plan. Patching is dnf on the box.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = "meal-prep-proxy" }
}
