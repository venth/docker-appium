FROM phusion/baseimage:0.9.1

MAINTAINER venth

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Install all dependencies
RUN apt-get update && \
    apt-get install -y wget openjdk-7-jre-headless libc6-i386 lib32stdc++6 && \
    apt-get install -y python make g++ lib32z1 supervisor zip unzip && \
    apt-get clean && \
    apt-get autoclean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install android tools + sdk
ENV ANDROID_HOME /opt/android-sdk-linux
ENV PATH $PATH:${ANDROID_HOME}/tools:$ANDROID_HOME/platform-tools

# Set up insecure default key
RUN mkdir -m 0750 /.android
ADD files/insecure_shared_adbkey /.android/adbkey
ADD files/insecure_shared_adbkey.pub /.android/adbkey.pub

RUN wget -qO- "http://dl.google.com/android/android-sdk_r24.3.4-linux.tgz" | tar -zx -C /opt && \
    echo y | android update sdk --no-ui --all --filter platform-tools --force

# Install android tools + sdk
# SDK 17 is needed for Selendroid (you can install any SDK >= 17)
RUN echo y | android update sdk --no-ui --all --filter build-tools-23.0.0 --force && \
    echo y | android update sdk --no-ui --all -t `android list sdk --all|grep "SDK Platform Android 4.2.2, API 17"|awk -F'[^0-9]*' '{print $2}'` && \
    rm -rf /tmp/*

# Create applicative user
RUN useradd -m -s /bin/bash appium
USER appium
ENV HOME /home/appium

# Install NodeJs
ENV node_version v0.12.7
RUN wget -qO- -P ${HOME} https://nodejs.org/dist/${node_version}/node-${node_version}.tar.gz | tar -zx -C /home/appium && \
    cd ${HOME}/node-${node_version}/ && ./configure --prefix=${HOME}/apps && \
    make && \
    make install && \
    rm -rf ${HOME}/node-${node_version} /tmp/*

# Prepare npm layout
RUN mkdir "${HOME}/.npm-packages"
ENV NPM_PACKAGES "${HOME}/.npm-packages"
RUN echo "prefix=${NPM_PACKAGES}" > ${HOME}/.npmrc
ENV NODE_PATH "${NPM_PACKAGES}/lib/node_modules:$NODE_PATH"

# Install appium
ENV PATH $PATH:${HOME}/apps/bin
RUN ${HOME}/apps/bin/npm install -g appium && \
    rm -rf /tmp/*

# BUGFIX: Add fixed unlock (current one not working with SDK 21 - tested on emulators)
RUN rm ${NPM_PACKAGES}/lib/node_modules/appium/build/unlock_apk/unlock_apk-debug.apk
ADD unlock_apk-debug.apk ${NPM_PACKAGES}/lib/node_modules/appium/build/unlock_apk/

USER root
ENV HOME /root

# APK directory for appium
RUN mkdir /apk && chown appium /apk
VOLUME /apk

# Expose appium server
EXPOSE 4723

# Configure supervisor
ENV APPIUM_ARGS "${APPIUM_ARGS}"
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Run supervisor
CMD ["/usr/bin/supervisord"]
