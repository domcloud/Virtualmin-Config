#!/bin/bash

if [ -f /etc/lsb-release ]; then 
  rsync -r ./lib/Virtualmin /usr/share/perl5
elif [ -f /etc/redhat-release ]; then 
  rsync -r ./lib/Virtualmin /usr/share/perl5/vendor_perl
fi


