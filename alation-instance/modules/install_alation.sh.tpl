#!/bin/bash

echo
echo "Install tools"
sudo yum install epel-release -y
sudo yum install awscli jq -y
AWS_ACCESS_KEY_ID=${aws_key}
AWS_SECRET_ACCESS_KEY=${aws_secret}
aws s3 sync --no-progress --exclude "*" \
  --include "${license_key_name}" \
  --include django_bootstrap.py \
  --include "${alation_rpm_name}" \
  s3://alation-ps/msullivan/rpm/ /home/centos/

MAIL_HOST=imap.everyone.net
MAIL_USER=${alation_email_username}
MAIL_PASS="${alation_email_password}"

echo "Confirm RPM"
rpm -K ${alation_rpm_name} || (echo "** RPM corrupted" && exit)

echo
echo "Install rpm"
sudo rpm -ivh ${alation_rpm_name}

echo
echo "Initialize Alation"
sudo /etc/init.d/alation init /data /backup

echo
echo
echo "Start Alation"
sudo systemctl start alation


echo "copy license file to location"
sudo mv ${license_key_name} /opt/alation/alation/data1/site_data/config/alation.lic
sudo chown alation:alation /opt/alation/alation/data1/site_data/config/alation.lic

echo "Copy bootstrap file"
sudo mv django_bootstrap.py /opt/alation/alation/opt/alation/django/rosemeta/one_off_scripts
sudo chown alation:alation /opt/alation/alation/opt/alation/django/rosemeta/one_off_scripts/django_bootstrap.py

echo "Apply license"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_action apply_license"
echo "Setting base url"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.install.base_url -s https://${alation_dnsname_prefix}.alationproserv.com"
echo "Enable workflow"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.feature_flags.enable_workflows_service -s True"
echo "Enable policy center"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.feature_flags.enable_policy_center -s True"
echo "Enable data governance"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.feature_flags.enable_governance_dashboard -s True"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.feature_flags.enable_governance_app -s True"
echo "Enable health check"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "/opt/alation/ops/actions/alationadmin/enable_datadog"
echo "Restart web process"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_supervisor restart web:uwsgi"


sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.install.install_wizard_complete -s True"

echo "Enable AA"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.feature_flags.enable_alation_analytics_v2 -s True"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.feature_flags.enable_analytics_v2_leaderboard -s True"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.install.install_wizard_complete -s True"
echo "Setup email"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.email.use_builtin -s False"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.email.host -s $MAIL_HOST"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.email.email_user -s $MAIL_USER"
sudo chroot /opt/alation/alation /bin/su - alation -c 'alation_conf alation.email.email_password -s "$MAIL_PASS"'

echo "Setup steward sync"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf stewardship.curation_progress.sync_objects.schedule.hour -s 9"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf stewardship.curation_progress.sync_objects.schedule.minute -s 0"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf stewardship.curation_progress.sync_objects.schedule.day -s 1"


echo "Setup first user as serveradmin"
sudo chroot /opt/alation/alation /bin/su - alation -c "cd /opt/alation/django/rosemeta/one_off_scripts && python django_bootstrap.py -a createUser -e \"${alation_firstuser_name}\"  -p \"${alation_firstuser_password}\""

echo "SETUP THE ALATION DB"
echo "${alation_rosemeta_db_password}" | sudo tee -a /opt/alation/alation/home/alation/p.txt
sudo chown alation:alation /opt/alation/alation/home/alation/p.txt
sudo chroot /opt/alation/alation /bin/su - alation -c "cd /opt/alation/django && python manage.py initialize_alation_db -u \"${alation_firstuser_name}\" < /home/alation/p.txt"
sudo rm /opt/alation/alation/home/alation/p.txt

echo "SETUP HYDRA / CONTAINER SERVICE PLUS DOCKER COMPOSE"
sudo yum install `find /opt/alation/alation/opt/addons/alation_container_service -name "alation-container-service*.rpm"` -y
sudo yum install /opt/alation/alation/opt/addons/hydra/hydra.rpm -y
echo '[agent]' |sudo tee -a /etc/hydra/hydra.toml
echo 'address="localhost:81"' | sudo tee -a /etc/hydra/hydra.toml
sudo systemctl start docker
sudo service hydra start
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.hydra_node.agent.hostname -s localhost"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.hydra_node.agent.port -s 81"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_conf alation.hydra_node.agent.tls_disabled -s True"

echo "Setup AA"
echo "install docker compose"
sudo curl -L "https://github.com/docker/compose/releases/download/1.28.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
echo "Download AAV2 using bootstrap script"
curl `sudo chroot /opt/alation/alation /bin/su - alation -c "cd /opt/alation/django/rosemeta/one_off_scripts && python django_bootstrap.py -a saveAAV2_url"|grep http` -o aav2.tar

sudo mkdir -p /opt/alation-analytics
sudo tar -C /opt/alation-analytics -xvf aav2.tar
sudo `find /opt/alation-analytics/ -name "*installer*"` -p ${alation_firstuser_password} -a localhost -d /opt/alation-analytics/

sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_supervisor restart all"
echo "Set pgsql password"
sudo chroot /opt/alation/alation /bin/su - alation -c "alation_conf alation_analytics-v2.pgsql.password -s ${alation_firstuser_password}"
echo "Restart web service"
sudo chroot /opt/alation/alation /bin/su - alationadmin -c "alation_supervisor restart web:* celery:*"

echo "Create access token"
curl -X POST -H "Content-Type: application/x-www-form-urlencoded" http://localhost/integration/v1/createAPIAccessToken/ --data "user_id=1&refresh_token=`cat /opt/alation/alation/home/alation/refresh_token.txt`" > /tmp/access_token
API_ACCESS_TOKEN=`cat /tmp/access_token | jq -r .api_access_token `

echo "Initialize AA database"
curl --request POST --url http://localhost/admin/ajax/aav2_migration/ \
     --header "TOKEN: $API_ACCESS_TOKEN" \
     --header 'content-type: application/json'
echo "Add script to crontab to start AA for reboot"
echo "@reboot /usr/local/bin/docker-compose -f /opt/alation-analytics/docker-compose.yaml up -d" |sudo tee -a /var/spool/cron/root
echo "0 9 * * * /sbin/shutdown -h now" |sudo tee -a /var/spool/cron/root
