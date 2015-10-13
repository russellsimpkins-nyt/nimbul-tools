#!/bin/bash
# Version: 0.2.10-1

STARTTIME=$(date +%s)

# all output goes to syslog (/var/log/messages), duplicated to stderr
exec > >(logger -s -t demo-app-bootstrap)
exec 2> >(logger -s -t demo-app-bootstrap)

set -eux
set -o pipefail


# facter file to expose user-data to as puppet facts
aws_facts="/etc/facter/facts.d/user_data.sh"
mkdir -p $(dirname $aws_facts)
cat >$aws_facts <<EOF
#!/bin/bash

# turns AWS user-data as Facts to be used by puppet
# prefix all names with "aws_",  quote all values with spaces

curl -fs http://169.254.169.254/latest/user-data |\\
  sed 's/^/aws_/' |\\
  sed 's/=\\(.*[ \\t].*\\)/="\\1"/'

#Add a newline after the last of the modified curl'ed vars
echo

#Throw in region - user-data only defines region_code, not the region - but we can get that from the
#identity document.  Implemented as a param default just in case it pops up in user-data sometime
echo "aws_region=\${aws_region:-$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document| grep '"region" :*' |awk -F\" '{print $4}')}"
EOF

echo '#!/bin/bash' > /etc/instance_variables
curl -fs http://169.254.169.254/latest/user-data|sed 's/^/aws_/' |sed 's/=\(.*[ \t].*\)/=\"\1\"/' >> /etc/instance_variables
echo "" >> /etc/instance_variables
echo "aws_region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document| grep '"region" :*' |awk -F\" '{print \$4}')" >> /etc/instance_variables


chmod +x $aws_facts

# load the aws_ facts as local bash variables
source <($aws_facts)

# Turn off the mirror list and use base url only to improve caching with our internal proxy
sed -i  's/^mirrorlist/#mirrorlist/g' /etc/yum.repos.d/*.repo
sed -i  's/^#baseurl/baseurl/g' /etc/yum.repos.d/*.repo

# Turn off fatestmirror plugin
sed -i  's/^enabled=1/enabled=0/g' /etc/yum/pluginconf.d/fastestmirror.conf

# Customize the timeout value
grep -q '^timeout=' /etc/yum.conf && sed -i "s/^timeout.*/timeout=120/" /etc/yum.conf || echo "timeout=120" >> /etc/yum.conf

# Figure out our proxy
case "$aws_environment_code" in
    "prd") INSTALL_PROXY="proxy-squid-v1.prd.${aws_region_code}.nyt.net"
           INSTALL_PROXY_PORT=80
    ;;
    *)     INSTALL_PROXY="proxy-squid-v1.stg.${aws_region_code}.nyt.net"
           INSTALL_PROXY_PORT=80
    ;;
esac

# proxy doesn't work for rpmforge
if [ 1 == 2 ]; then 
  # Heartbeat check to see if the proxy is up
  if [ "200" != "$(curl -sL -w "%{http_code}" -o /dev/null --proxy "http://$INSTALL_PROXY:$INSTALL_PROXY_PORT/" --max-time 20 "http://yum.puppetlabs.com/el/6/products/x86_64/repodata/repomd.xml")" ]; then
      # If we don't get a 200 to a call on a supported repo, then we assume the proxy is not up and we
      # fallback to the Internet
      INSTALL_PROXY=""
  fi
   
  # Stick in proxy configuration if we have a proxy configured
  if [ ! -z "$INSTALL_PROXY" ]; then
      grep -q '^proxy=' /etc/yum.conf && sed -i "s/^proxy.*/proxy=http:\/\/${INSTALL_PROXY}:${INSTALL_PROXY_PORT}/" /etc/yum.conf || echo "proxy=http://${INSTALL_PROXY}:${INSTALL_PROXY_PORT}" >> /etc/yum.conf
  fi
fi
# Install new puppet from puppetlabs, it supports s3_enabled for yumrepo command !!!
# But only install if it hasn't been installed before.  This will allow for repeated bootstrap attempts
if [ -z "$(yum list installed |grep puppetlabs-release.noarch)" ]; then
    RPM_PROXY_ARGS="$(if [ ! -z "$INSTALL_PROXY" ]; then echo "--httpproxy "${INSTALL_PROXY}" --httpport ${INSTALL_PROXY_PORT}"; fi)"
    rpm -ivh $RPM_PROXY_ARGS http://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm
    yum -y install puppet
fi

# Download our puppet modules to standard location
puppet_dir=/usr/share/puppet
s3_root=s3://infrastructure-deploy-nyt-net/$aws_app_code/$aws_environment_code

# Y U NO S3 SYNC?
#
# According to https://github.com/aws/aws-cli/issues/599, "...if the
# file sizes are the same and the last modified time in s3 is greater
# (newer) than the local file, then we don't sync. This is the current
# behavior."  So this is a problem for us when we push puppet files
# that keep the same size, think "dev" changed to "prd".

#rm -f /etc/hiera.yaml
#rm -f /etc/puppet/hiera.yaml
#rm -rf /var/lib/hiera

#rm -rf /etc/puppet/modules/*
#rm -rf /etc/puppet/manifests/*

#aws s3 cp --recursive $s3_root/ci/puppet $puppet_dir
#ln -s /usr/share/puppet/hiera.yaml /etc/puppet/hiera.yaml
#ln -s /usr/share/puppet/hieradata /var/lib/hiera


function puppet_apply() {
    local retryNumber=${1:-1}

    if [ "$retryNumber" -gt "2" ]; then
        echo "We have reached the maximum retry amount for puppet - exiting"
        exit 1
    elif [ "$retryNumber" -eq "1" ]; then
        echo "Applying puppet"
    else
        echo "Trying to apply puppet again after 30 seconds"
        sleep 30s
    fi

    puppet apply /usr/share/puppet/manifests/site.pp --environment ${aws_environment_name,,} --color false --verbose --detailed-exitcodes || {
        # handle bug https://tickets.puppetlabs.com/browse/PUP-2754 where puppet doesn't report exit codes as expected
        # The code below deals with behavior of --detailed-exitcodes
        puppet_status=$?
        if [ $puppet_status -eq 2 ]; then
            echo "Puppet Changes Applied"
            puppet_status=0
        elif [ $puppet_status -eq 4 -o $puppet_status -eq 6 ]; then
            echo "Puppet failures detected"
            puppet_apply $(($retryNumber + 1))
        else
            echo "Warning: unexpected puppet exit code returned"
        fi
        ENDTIME=$(date +%s)
        echo "Done bootstrapping in $(($ENDTIME - $STARTTIME)) seconds"
        exit $puppet_status
    }
}

