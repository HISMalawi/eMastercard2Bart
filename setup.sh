#!/bin/bash

RUBY_TARGET_VERSION=2.5.3

sudo apt install build-essential ruby-dev default-libmysqlclient-dev

if [ -e ~/.rvm/scripts/rvm ]; then
  source ~/.rvm/scripts/rvm
elif [ -e /usr/share/rvm/scripts/rvm ]; then
  source /usr/share/rvm/scripts/rvm
elif [ -e /usr/local/rvm/scripts/rvm ]; then
  source /usr/local/rvm/scripts/rvm
else
  source /usr/local/share/rvm/scripts/rvm
fi

echo "Using rvm: `which rvm`"

if [ -z `rvm list strings | grep "ruby-$RUBY_TARGET_VERSION"` ]; then
  echo "Installing ruby-$RUBY_TARGET_VERSION"
  rvm install ruby-$RUBY_TARGET_VERSION || { echo "Failed to install ruby-$RUBY_TARGET_VERSION"; exit 255; }
fi

rvm use $RUBY_TARGET_VERSION

ruby_installed_version=$(ruby --version | grep -e "ruby $RUBY_TARGET_VERSION")
if [ -z "$ruby_installed_version" ]; then
  echo "Ruby $RUBY_TARGET_VERSION not found; make sure you have rvm installed."
  exit 255
fi

bundler_version=$(gem list | grep -e '^bundler .*')
if [ -z "$bundler_version" ]; then
  echo "Installing ruby bundler"
  gem install bundler || { echo "Failed to install Ruby bundler"; exit 255; }
fi

bundle install || { echo "Failed to setup dependencies"; exit 255; }

cat <<EOF
Setup has successfully completed. Before you start the migration, please make
sure you edit 'config.yaml' accordingly. Refer to README.md on how to do this.
EOF