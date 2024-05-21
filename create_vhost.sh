#!/bin/bash

# Function to create a PHP vhost
create_php_vhost() {
    echo "Creating Nginx PHP vhost..."
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
    echo "Creating Nginx Reverse Proxy vhost..."
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
    echo "Creating Nginx HTML vhost..."
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

# Function to create a vhost for Apache2
create_apache_vhost() {
    echo "Creating Apache php vhost..."
    sudo tee /etc/apache2/sites-available/$name.local.conf > /dev/null <<EOF
<VirtualHost *:81>
    ServerAdmin dev@ricardoalvarez.com.co
    ServerName $url

    DocumentRoot $directory

    <Directory $directory>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Order allow,deny
        allow from all
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$name-error.log
    CustomLog \${APACHE_LOG_DIR}/$name-access.log combined

</VirtualHost>
EOF
}
# Function to validate and edit apache2.conf
validate_and_edit_apache_conf() {
    conf_file="/etc/nginx/sites-available/apache2.conf"

    if [ -f "$conf_file" ]; then
        echo "apache2.conf exists. Editing server_name..."
        if grep -q "server_name" "$conf_file"; then
            sudo sed -i "s/server_name \(.*\);/server_name \1 $url;/" "$conf_file"
        else
            echo "server_name not found. Adding serve_name..."
            echo "server_name $url;" | sudo tee -a "$conf_file" > /dev/null
        fi
    else
        echo "apache2.conf does not exist. Creating and adding server_name..."
        echo "server_name $url;" | sudo tee "$conf_file" > /dev/null
        # Create the default vhost
        echo "Creating default vhost..."
        sudo tee /etc/nginx/sites-available/apache2.conf > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $url;

    location / {
        proxy_pass http://192.168.100.10:81;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
        sudo ln -s /etc/nginx/sites-available/apache2.conf /etc/nginx/sites-enabled/
    fi
}

# Prompt user for input
read -p "Enter the vhost name: " name
read -p "Enter the vhost URL (e.g., example.local): " url

# Show options to the user
echo "Select the type of vhost you want to create:"
echo "1) VHOST PHP (Nginx)"
echo "2) VHOST PROXY REVERSE (Nginx)"
echo "3) VHOST HTML (Nginx)"
echo "4) VHOST PHP (Apache2)"
read -p "Option: " option

# Create the vhost based on the selected option
case $option in
    1)
        read -p "Enter the vhost directory (e.g., /var/www/project): " directory
        read -p "Enter the PHP-FPM version (e.g., 7.4): " php_version
        create_php_vhost
        ;;
    2)
        read -p "Enter the proxy host and port (e.g., localhost:3000): " host_port
        create_proxy_vhost
        ;;
    3)
        read -p "Enter the vhost directory (e.g., /var/www/project): " directory
        create_html_vhost
        ;;
    4)
        read -p "Enter the vhost directory (e.g., /var/www/project): " directory
        create_apache_vhost

        # Enable the new site Apache2
        sudo a2ensite $name.local.conf
	validate_and_edit_apache_conf
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

# Enable the new site and reload Nginx
if [ "$option" -ne 4 ]; then
    sudo ln -s /etc/nginx/sites-available/$name.local.conf /etc/nginx/sites-enabled/
fi
sudo systemctl reload apache2
sudo nginx -t && sudo systemctl reload nginx

echo "Vhost created and enabled successfully."

# Print server IP and assigned vhost URL
server_ip=$(hostname -I | awk '{print $1}')
echo "$server_ip        $url"
