#!/bin/bash

# Function to create a PHP vhost
create_php_vhost() {
    echo "Creating PHP vhost..."
    sudo tee /etc/nginx/sites-available/$name.local.conf > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $url;

    root $directory;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \\.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php$php_version-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
}

# Function to create a reverse proxy vhost
create_proxy_vhost() {
    echo "Creating Reverse Proxy vhost..."
    sudo tee /etc/nginx/sites-available/$name.local.conf > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $url;

    location / {
        proxy_pass http://$host_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
}

# Function to create an HTML vhost
create_html_vhost() {
    echo "Creating HTML vhost..."
    sudo tee /etc/nginx/sites-available/$name.local.conf > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $url;

    root $directory;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
}

# Prompt user for input
read -p "Enter the vhost name: " name
read -p "Enter the vhost URL (e.g., example.local): " url

# Show options to the user
echo "Select the type of vhost you want to create:"
echo "1) PHP"
echo "2) Reverse Proxy"
echo "3) HTML"
read -p "Option: " option

# Create the vhost based on the selected option
case $option in
    1)
        read -p "Enter the vhost directory (e.g., /var/www/html/project): " directory
        read -p "Enter the PHP-FPM version (e.g., 7.4): " php_version
        create_php_vhost
        ;;
    2)
        read -p "Enter the proxy host and port (e.g., http://localhost:3000): " host_port
        create_proxy_vhost
        ;;
    3)
        read -p "Enter the vhost directory (e.g., /var/www/html/project): " directory
        create_html_vhost
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

# Enable the new site and reload Nginx
sudo ln -s /etc/nginx/sites-available/$name.local.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

echo "Vhost created and enabled successfully."

# Print server IP and assigned vhost URL
server_ip=$(hostname -I | awk '{print $1}')
echo "$server_ip	$url"