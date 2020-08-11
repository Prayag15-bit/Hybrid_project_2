//=============================
//Function to configure AWS Console
//=============================
provider "aws" {
	region = "ap-south-1"
	profile = "prayag"
}

//=======================
//Function to create a key-pair
//=======================
resource "tls_private_key" "Privatekey" {
	algorithm   = "RSA"
}

resource "local_file" "private_key_access"{
	content = tls_private_key.Privatekey.private_key_pem
	filename = "privatekey.pem"
}

resource "aws_key_pair" "mypublickey"{
	key_name = "mykey6396"
	public_key = tls_private_key.Privatekey.public_key_openssh
}

//===========================
//Function to create security-group
//===========================
resource "aws_security_group" "security" {
	name        = "security"
	description = "To allow SSH and HTTP connectivity"
	vpc_id      = "vpc-d4eff2bc"

	ingress {
		description = "HTTP"
		from_port  = 80
		to_port     = 80
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
}

	ingress {
		description = "SSH"
		from_port   = 22
		to_port     = 22
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
}

	ingress {
		description = "NFS"
		from_port   = 2049
		to_port     = 2049
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
}

	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
}

	tags = {
		Name = "security"
  	}
}

//=============================
//Function to launch an EC2 instance
//=============================
resource "aws_instance" "EC2_launch"{
	ami = "ami-052c08d70def0ac62"
	instance_type = "t2.micro"
	key_name = "mykey6396"
	security_groups = ["security"]
	
	connection {
		type = "ssh"
		user = "ec2-user"
		private_key = tls_private_key.Privatekey.private_key_pem
		host = aws_instance.EC2_launch.public_ip
	}
	provisioner "remote-exec" {
		inline = [
		"sudo yum install -y httpd git",
		"sudo systemctl restart httpd",
		"sudo systemctl enable httpd"
		]
	}

	tags = {
		Name = "myinstance"
 	}
}

//=================================
//Function to create an EFS storage
//=================================
resource "aws_efs_file_system" "MyEFS" {
	creation_token = "MyEFS"

	tags = {
		Name = "MyEFS"
	} 
}

//=============================
//Function to mount EFS in our Instance
//=============================
resource "aws_efs_mount_target" "alpha" {
	file_system_id = aws_efs_file_system.MyEFS.id
	subnet_id      = aws_instance.EC2_launch.subnet_id
	security_groups = ["security"]              						 
}

//==========================
//Function to create an S3 bucket
//==========================
resource "aws_s3_bucket" "S3_launch" {
	bucket = "sds-zeldris-bucket"
	acl    = "public-read"	
	versioning {
		enabled = true
	}
}

//============================================
//Function to PULL the GitHub code in the local system
//============================================
resource "null_resource" "Pulling_GIT_code"{
	provisioner "local-exec" {
		command = "git clone https://github.com/Prayag15-bit/Hybrid_project.git C:/Users/hp/Desktop/LinkedIn work/Terraform_Workspace/HYBRID"
	}
}

//===================================
//Function to provide resource to the bucket
//===================================
resource "aws_s3_bucket_object" "resource_provider" {
	bucket = aws_s3_bucket.S3_launch.bucket
	key    = "HYBRID_image.jpg"
 	source = "C:/Users/hp/Desktop/LinkedIn work/Terraform_Workspace/HYBRID/HYBRID_image.jpg"
}

//====================================
//Function to create CloudFront for S3 bucket
//====================================
resource "aws_cloudfront_distribution" "S3_coudfront_launch" {	
	origin {
		domain_name = aws_s3_bucket.S3_launch.bucket_regional_domain_name
		origin_id   = "S3-sds-zeldris-bucket"
		custom_origin_config{
			http_port = 80
			https_port = 80
			origin_protocol_policy = "match-viewer"
			origin_ssl_protocols = ["TLSv1","TLSv1.1","TLSv1.2"]
			}
	}
	enabled = true
	default_cache_behavior {
		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods   = ["GET", "HEAD"]
		target_origin_id = "S3-sds-zeldris-bucket"

    		forwarded_values {
      		query_string = false

		cookies {
			forward = "none"
			}
		}

		viewer_protocol_policy = "allow-all"
		min_ttl                = 0
		default_ttl            = 3600
		max_ttl                = 86400
	}

	restrictions {
		geo_restriction {
			restriction_type = "none"
		}
	}

	viewer_certificate {
		cloudfront_default_certificate = true
	}
}

//====================================
//Function to mount the code in the EC2 instance
//====================================
resource "null_resource" "Mounting_process"{

connection{
type = "ssh"
user = "ec2-user"
private_key = tls_private_key.Privatekey.private_key_pem
host = aws_instance.EC2_launch.public_ip
}
provisioner "remote-exec"{
inline=[
"sudo yum install amazon-efs-utils nfs-utils -y",
"sudo chmod -R ugo+rw /etc/fstab",
"sudo echo '#{aws_efs_file_system.MyEFS.id}:/var/www/html efs tls, netdev 0 0' >> /etc/fstab",
"sudo mount -a -t efs, nfs4 defaults",
"sudo cd /var/www/html/",
"sudo rm -r -f *",
"sudo git clone https://github.com/Prayag15-bit/Hybrid_project.git /var/www/html/",
"sudo su << EOF",
"echo 'https://${aws_cloudfront_distribution.S3_coudfront_launch.domain_name}/${aws_s3_bucket_object.resource_provider.key}' > /var/www/html/HYBRID_page.html",
"EOF"
]
}
}

//=======================================
//Function to deploy the webserver for public use
//=======================================
resource "null_resource" "WebPage_deploy"{
depends_on=[
null_resource.Mounting_process, aws_s3_bucket_object.resource_provider,
]
provisioner "local-exec"{
command = "chrome ${aws_instance.EC2_launch.public_ip}"
}
}

//=================
//END OF THE CODE
//=================	



	
































