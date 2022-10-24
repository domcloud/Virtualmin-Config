package Virtualmin::Config::Plugin::ProFTPd;
use strict;
use warnings;
no warnings qw(once);
use parent 'Virtualmin::Config::Plugin';

our $config_directory;
our (%gconfig, %miniserv);
our $trust_unknown_referers = 1;

my $log = Log::Log4perl->get_logger("virtualmin-config-system");

sub new {
  my ($class, %args) = @_;

  # inherit from Plugin
  my $self = $class->SUPER::new(name => 'ProFTPd', %args);

  return $self;
}

# actions method performs whatever configuration is needed for this
# plugin. XXX Needs to make a backup so changes can be reverted.
sub actions {
  my $self = shift;

  use Cwd;
  my $cwd  = getcwd();
  my $root = $self->root();
  chdir($root);
  $0 = "$root/virtual-server/config-system.pl";
  push(@INC, $root);
  eval 'use WebminCore';    ## no critic
  init_config();

  $self->spin();
  eval {
    foreign_require("init", "init-lib.pl");
    init::enable_at_boot("proftpd");
    foreign_require("proftpd", "proftpd-lib.pl");
    my $conf = proftpd::get_config();
    if ($gconfig{'os_type'} eq 'freebsd') {

      # This directory is missing on FreeBSD
      make_dir("/var/run/proftpd", oct(755));

      # UseIPv6 doesn't work on FreeBSD
      proftpd::save_directive("UseIPv6", [], $conf, $conf);
    }

    # Create a virtualmin.conf file and Include it
    # Debian has /etc/proftpd/conf.d, CentOS we create it.
    my $config_directory = "/etc/proftpd/conf.d";
    if (!-d $config_directory) {
      $log->info('/etc/proftpd/conf.d missing. Creating it.');
      use File::Path 'make_path';
      make_path($config_directory, {mode => oct(755)});
    }

    # Where are certs and keys stored?
    my ($keyfile, $certfile);
    if ($gconfig{'os_type'} =~ /debian-linux|ubuntu-linux/) {
      $certfile = '/etc/ssl/certs/proftpd.crt';
      $keyfile  = '/etc/ssl/private/proftpd.key';

      # Add to end of file, if not already there Include /etc/proftpd/conf.d
      proftpd::save_directive('Include',
        ['/etc/proftpd/modules.conf', '/etc/proftpd/conf.d'],
        $conf, $conf);

    }
    elsif ($gconfig{'os_type'} eq 'redhat-linux') {
      $certfile = '/etc/pki/tls/certs/proftpd.pem';
      $keyfile  = '/etc/pki/tls/private/proftpd.pem';
      proftpd::save_directive('Include', ['/etc/proftpd/conf.d'], $conf, $conf);
    }
    else {
      $log->warn("No configuration available for OS type $gconfig{'os_type'}.");
      die "Skipping additional ProFTPd configuration for this OS.";
    }


    # generate TLS cert/key pair
    my $hostname = get_system_hostname();
    my $org      = "Self-signed for $hostname";

    $log->info('Generating a self-signed certificate for TLS.');
    $self->logsystem(
      "openssl req -new -x509 -days 3650 -nodes -out $certfile -keyout $keyfile -subj '/C=NA/ST=NA/L=NA/O=$org/CN=$hostname'"
    );

    # Generate ssh key pairs
    if (!-f '/etc/proftpd/ssh_host_ecdsa_key') {
      $self->logsystem(
        "ssh-keygen -f /etc/proftpd/ssh_host_ecdsa_key -t ecdsa -N '' -m PEM");
    }
    if (!-f '/etc/proftpd/ssh_host_rsa_key') {
      $self->logsystem(
        "ssh-keygen -f /etc/proftpd/ssh_host_rsa_key -t rsa -N '' -m PEM");
    }

    my $vmconf = <<"EOF";
# Use standard passive ports
<Global>
  PassivePorts 49152 65535
</Global>

# chroot users into their home by default
DefaultRoot ~

# Enable TLS
LoadModule mod_tls.c
TLSEngine                     on
TLSRequired                   off
TLSRSACertificateFile         $certfile
TLSRSACertificateKeyFile      $keyfile
TLSOptions                    NoCertRequest NoSessionReuseRequired
TLSVerifyClient               off
TLSLog                        /var/log/proftpd/tls.log
<IfModule mod_tls_shmcache.c>
  TLSSessionCache             shm:/file=/var/run/proftpd/sesscache
</IfModule>

# VirtualHost for SFTP (FTP over SSH) port
LoadModule mod_sftp.c
<VirtualHost 0.0.0.0>
  SFTPEngine on
  SFTPLog /var/log/proftpd/sftp.log

  # Configure the server to listen on 2222 (openssh owns 22)
  Port 2222

  # Configure the RSA and ECDSA host keys, using the same host key
  # files that OpenSSH uses.
  SFTPHostKey /etc/proftpd/ssh_host_rsa_key
  SFTPHostKey /etc/proftpd/ssh_host_ecdsa_key

  # Configure the file used for comparing authorized public keys of users.
  SFTPAuthorizedUserKeys file:~/.sftp/authorized_keys

  # Enable compression
  SFTPCompression delayed

  # More then FTP max logins, as there are more ways to authenticate
  # using SSH2.
  MaxLoginAttempts 6
</VirtualHost>
EOF

    # Write out virtualmin.config
    open my $VMH, '>', '/etc/proftpd/conf.d/virtualmin.conf';
    print $VMH $vmconf;
    close $VMH;

    # If SELinux is installed enable the right boolean
    # For SFTP?
    if (-x '/usr/sbin/setsebool') {
      $self->logsystem('setsebool -P ftpd_full_access 1');
    }

    # Generate a basic config, subbing in the right variables.
    flush_file_lines();
    
    # Create initial site file to satisfy config check
    my $site_conf = "$ENV{'WEBMIN_CONFIG'}/proftpd/site";
    if (! -r $site_conf) {
      my $ver;
      my %site_conf;
      $ver = proftpd::get_proftpd_version();
      $site_conf{'version'} = $ver;
      write_file($site_conf, \%site_conf);
    }

    # Restart ProFTPd
    init::restart_action("proftpd");

    $self->done(1);    # OK!
  };
  if ($@) {
    $self->done(0);    # NOK!
  }
}

1;
