EC2 IAM role for RDS DB Connect
===
Terraform module to create an EC2 role to be assumed for [requesting RDS DB connect credentials]().
Allows an EC2 instance to assume the role required to request temporary credentials for connecting to an RDS MySQL or PostgreSQL database.

# Examples
## Example with VPC, EC2 and DB
This example creates a DB using [this module](https://registry.terraform.io/modules/voquis/rds-enhanced-monitoring/aws/) (defaults to MySQL) inside a VPC using [this module](https://registry.terraform.io/modules/voquis/vpc-subnets-internet/aws).
A publicly-accessible EC2 instance is created to verify connectivity:
```terraform
# Create database
module "database" {
  source                 = "voquis/rds-enhanced-monitoring/aws"
  version                = "0.0.1"
  subnet_ids             = module.networking.subnets[*].id
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.db.id]
}

# Create role for EC2 instances to acquire credentials
module "ec2_role_db_connect" {
  source         = "voquis/ec2-role-rds-db-connect/aws"
  version        = "0.0.1"
  db_resource_id = module.database.db_instance.resource_id
}

# EC2 Security group to allow public access
resource "aws_security_group" "ec2" {
  vpc_id = module.networking.vpc.id
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["8.8.8.8/32"]
  }
}

# Create network interface for instance in subnet 1
resource "aws_network_interface" "this" {
  subnet_id   = module.networking.subnets[0].id
  security_groups = [aws_security_group.ec2.id]
}

# Create EC2 instance (ubuntu)
resource "aws_instance" "web" {
  ami                    = "ami-0eb89db7593b5d434"
  instance_type          = "t2.micro"
  iam_instance_profile   = module.ec2_role_db_connect.iam_instance_profile.id
  key_name               = "my-key"
  network_interface {
    network_interface_id = aws_network_interface.this.id
    device_index         = 0
  }
}
```

The instance should then be accessible with ```ssh -i my-key ubuntu@1.2.3.4```.
To acquire [RDS credentials](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.Connecting.AWSCLI.html), use the following (replacing hostname with your instance endpoint, region and username):
```shell
aws rds generate-db-auth-token --hostname terraform-123.abc.eu-west-2.rds.amazonaws.com --port 3306 --region us-west-2 --username jane_doe
```
