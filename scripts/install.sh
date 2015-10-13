#!/bin/bash
set -e

# Maybe not needed
# yum install -y python-boto

# bring down some helpful utility scripts
aws s3 cp s3://infrastructure-deploy-nyt-net/du/dev/shared/install-include.sh /tmp/
aws s3 cp s3://infrastructure-deploy-nyt-net/du/dev/shared/check-ebs-volumes.sh /tmp/
aws s3 cp s3://infrastructure-deploy-nyt-net/du/dev/rpms/yum-plugin-s3-iam-1.0-1.noarch.rpm /tmp/
aws s3 cp s3://infrastructure-deploy-nyt-net/du/dev/rpms/puppetlabs-release-el-6.noarch.rpm /tmp/
rpm -ivh /tmp/yum-plugin-s3-iam-1.0-1.noarch.rpm || true
rpm -Uvh /tmp/puppetlabs-release-el-6.noarch.rpm || true
echo "[platform]
name=platform
baseurl=http://infrastructure-deploy-nyt-net.s3.amazonaws.com/du/dev/${aws_app_code}/${aws_environment_code}/${aws_cluster_code}/rpms
enabled=1
s3_enabled=1
gpgcheck=0
" > /etc/yum.repos.d/platform.repo

# this is the repo to the shared stuff
aws s3 cp s3://infrastructure-deploy-nyt-net/du/dev/rpms/platform.repo /etc/yum.repos.d/

# this creates /etc/instance_variables
source /tmp/install-include.sh

# instance variables
source /etc/instance_variables

# add mounts
/bin/bash /tmp/check-ebs-volumes.sh

# add puppet master
yum history sync
yum install -y puppet-server emacs-nox

# we should now have /var/nyt with enough space to store data
aws s3 sync s3://infrastructure-deploy-nyt-net/${aws_app_code}/${aws_environment_code}/${aws_cluster_code}/etc /etc

set +ue
echo "Exec {
  path => ['/usr/local/bin','/usr/local/sbin',
           '/usr/bin',
           '/usr/sbin',
           '/bin',
           '/sbin',
           '/var/nyt/bin',
           '/root/bin']
}

Package{
  allow_virtual => false
}

stage { 'prereqs':
  before => Stage['main'],
}

stage { 'final':
  require => Stage['main'],
}

node '$(hostname -f)' {
    include roles::${aws_cluster_code}
}" > /etc/puppet/manifests/site.pp

echo "[main]
    logdir=/var/log/puppet
    vardir=/var/lib/puppet
    ssldir=/var/lib/puppet/ssl
    rundir=/var/run/puppet
    factpath=\$vardir/lib/facter

[master]
    server = $(hostname -f)

[agent]
    # The file in which puppetd stores a list of the classes   
    # associated with the retrieved configuratiion.  Can be loaded in
    # the separate ``puppet`` executable using the ``--loadclasses`` 
    # option.
    # The default value is '$confdir/classes.txt'.
    classfile = \$vardir/classes.txt

    # Where puppetd caches the local configuration.  An
    # extension indicating the cache format is added automatically.
    # The default value is '$confdir/localconfig'.
    localconfig = \$vardir/localconfig

    # set master to this host
    server = $(hostname -f)
    runinterval = 30m
    report = false
" > /etc/puppet/puppet.conf



rm -rf /ssl
rm -rf /var/lib/puppet/ssl
yum install -y puppet puppet-server du-config

mkdir /var/nyt/gocode
export GOPATH=/var/nyt/gocode
echo GOPATH=/var/nyt/gocode >> /etc/sysconfig/puppetmaster
echo GOPATH=/var/nyt/gocode >> /etc/sysconfig/puppet

/etc/init.d/puppetmaster restart || true

/bin/nice /usr/bin/puppet agent --test
/bin/nice /usr/bin/puppet agent --test
ret=$?

if [ $ret -eq 2 ]; then
    ret=0
fi

exit $ret

for e in /etc/sysconfig/puppet /etc/sysconfig/puppetmaster; do
    echo "
if [ -f /etc/cloudrc ]; then
    . /etc/cloudrc
fi
NICELEVEL=10" > $e
done

/sbin/chkconfig --add puppetmaster
/sbin/chkconfig --remove puppet
/sbin/chkconfig --level 2345 puppetmaster on
/sbin/service puppetmaster restart


/var/nyt/bin/run-puppet-agent.sh
/var/nyt/bin/run-puppet-agent.sh

exit 0
