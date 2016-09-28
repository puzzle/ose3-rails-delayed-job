FROM centos/ruby-22-centos7

# ABOUT
# This image is based on a S2I image but used in standard 'docker build'
# fashion. This is done by triggering $STI_SCRIPTS_PATH/assemble while
# building.

USER root

LABEL io.k8s.description="Platform for building and running delayed job in conjunction with ruby on rails" \
      io.k8s.display-name="Ruby 2.2 container with delayed job workers" \
      io.openshift.tags="builder,ruby,ruby22,delayed job"

# SLOW STUFF
# Slow operations, kept at top of the Dockerfile so they're cached for most changes.

#RUN yum update -y && \
    #INSTALL_PKGS="sphinx" && \
    #yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    #yum clean all -y

# CONFIGURATION

### Rails
ENV RAILS_ENV=production \
    RAILS_ROOT=/opt/app-root/src

### Add configuration files.
#ADD /contrib/bin $STI_SCRIPTS_PATH

# PERMISSIONS

# TODO Why do we do this? Check with the fix-permissions call in $STI_SCRIPTS_PATH/assemble.
RUN chgrp -R 0 ./ && \
    chmod -R g+rw ./ && \
    find ./ -type d -exec chmod g+x {} + && \
    chown -R 1001:0 ./

# SOURCE / DEPENDENCIES

# (I): Add Gemfile, install the needed gems.
# Doing this before adding the rest of the source ensures that as long
# as neither Gemfile nor Gemfile.lock change, Docker will keep the installed
# bundle in the cache.
ONBUILD USER root
ONBUILD ADD ./Gemfile ./Gemfile.lock /tmp/src/
ONBUILD RUN chown -R 1001 /tmp/src/
ONBUILD USER 1001
ONBUILD RUN DISABLE_ASSET_COMPILATION=true $STI_SCRIPTS_PATH/assemble

# (II): Add the rest of the source.
ONBUILD USER root
ONBUILD ADD . /tmp/src/
ONBUILD RUN chown -R 1001 /tmp/src/
ONBUILD USER 1001
# This time, `assemble` will take advantage of the gems cached in (I),
# speeding up most builds.
ONBUILD RUN $STI_SCRIPTS_PATH/assemble

USER 1001

# ENTRYPOINT

CMD bundle exec rake jobs:work
