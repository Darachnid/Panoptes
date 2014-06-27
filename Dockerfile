FROM ubuntu:12.04
MAINTAINER Edward Paget <ed@zooniverse.org>

ENV LANG en_US.UTF-8

# Install tools & libs to compile everything
RUN apt-get update 
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-7-jre
RUN apt-get clean

# Install ruby-build
RUN apt-get install -y git-core && apt-get clean
RUN git clone https://github.com/sstephenson/ruby-build.git && cd ruby-build && ./install.sh

# Install jruby-1.7.12
ENV CONFIGURE_OPTS --disable-install-rdoc
RUN ruby-build jruby-1.7.12 /usr/local
RUN gem install bundler

WORKDIR /rails_app

ENV RAILS_ENV docker_dev
ADD Gemfile /rails_app/Gemfile
ADD Gemfile.lock /rails_app/Gemfile.lock
RUN bundle install

ADD ./ /rails_app

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
