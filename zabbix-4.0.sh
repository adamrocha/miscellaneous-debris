#!/usr/bin/env bash
# zabbix-server-4.0 deploy against ubuntu-16.04

wget https://repo.zabbix.com/zabbix/4.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.0-2+xenial_all.deb
sudo dpkg -i zabbix-release_4.0-2+xenial_all.deb
sudo apt update
sudo apt install zabbix-server-pgsql php-pgsql zabbix-frontend-php -y
sudo -u postgres createuser --pwprompt zabbix
sudo -u postgres createdb -O zabbix -E Unicode -T template0 zabbix
zcat /usr/share/doc/zabbix-server-pgsql/create.sql.gz | sudo -u zabbix psql zabbix
sudo sed -i 's/# DBHost=localhost/DBHost=/' /etc/zabbix/zabbix_server.conf
sudo systemctl start zabbix-server && sudo systemctl enable zabbix-server
sudo sed -i 's/# php_value date.timezone Europe\/Riga/php_value date.timezone America\/Los_Angeles/' /etc/apache2/conf-enabled/zabbix.conf
sudo apt install zabbix-agent -y && sudo systemctl start zabbix-agent && sudo systemctl enable zabbix-agent
sudo systemctl restart apache2
sudo add-apt-repository 'deb https://packagecloud.io/grafana/stable/debian/ stretch main'
curl https://packagecloud.io/gpg.key | sudo apt-key add -
sudo apt update
sudo apt install grafana
sudo systemctl daemon-reload
sudo systemctl start grafana-server
sudo systemctl status grafana-server
sudo systemctl enable grafana-server.service
