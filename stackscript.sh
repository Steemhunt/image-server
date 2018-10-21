# MARK: - System updates
sudo update-locale LANG=en_US.UTF-8 LANGUAGE= LC_CTYPE="en_US.UTF-8" LC_NUMERIC="en_US.UTF-8" LC_TIME="en_US.UTF-8" LC_COLLATE="en_US.UTF-8" LC_MONETARY="en_US.UTF-8" LC_MESSAGES="en_US.UTF-8" LC_PAPER="en_US.UTF-8" LC_NAME="en_US.UTF-8" LC_ADDRESS="en_US.UTF-8" LC_TELEPHONE="en_US.UTF-8" LC_MEASUREMENT="en_US.UTF-8" LC_IDENTIFICATION="en_US.UTF-8" LC_ALL=en_US.UTF-8
sudo locale-gen en_US.UTF-8

sudo apt-get update && sudo apt-get -y upgrade && sudo apt-get -y dist-upgrade && sudo apt-get -y autoremove

sudo dpkg-reconfigure tzdata

sudo vim /etc/ssh/sshd_config # change port to 2222
sudo service sshd restart

git clone git@github.com:Steemhunt/image-server.git

# MARK: -- rbenv & ruby
sudo apt-get install -y build-essential zlib1g-dev libssl-dev libreadline-gplv2-dev gcc libgsl0-dev
git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile
echo 'eval "$(rbenv init -)"' >> ~/.profile
exec $SHELL -l
git clone https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
sudo apt-get install libffi-dev # https://github.com/sstephenson/ruby-build/wiki#build-failure-of-fiddle-with-ruby-220
rbenv install 2.5.3
rbenv rehash && rbenv global 2.5.3
sudo ln -s ~/.rbenv/shims/ruby /usr/local/bin/ruby;sudo ln -s ~/.rbenv/shims/gem /usr/local/bin/gem
gem update --system && gem install bundler

