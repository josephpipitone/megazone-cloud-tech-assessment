#!/bin/bash

sudo yum update -y
sudo amazon-linux-extras install nginx1 -y
sudo systemctl start nginx
sudo systemctl enable nginx

# Ensure directory exists
sudo mkdir -p /usr/share/nginx/html

cat <<EOF | sudo tee /usr/share/nginx/html/index.html > /dev/null
<html>
<body>
<h1>Instance Metadata</h1>
<pre>$(curl http://169.254.169.254/latest/meta-data/)</pre>
</body>
</html>
EOF
