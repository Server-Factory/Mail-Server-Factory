FROM fedora:33

ARG MAIN_PORT
ARG UTILS_HOME
ARG PROXY_HOME
ARG FACTORY_SERVICE
ARG proxy_host_ip

ENV MAIN_PORT "$MAIN_PORT"
ENV UTILS_HOME "$UTILS_HOME"
ENV PROXY_HOME "$PROXY_HOME"
ENV FACTORY_SERVICE "$FACTORY_SERVICE"
ENV proxy_host_ip "$proxy_host_ip"

COPY Utils "$UTILS_HOME"

RUN dnf install -y libnet curl wget telnet net-tools iputils openssl findutils && \
    sh "${UTILS_HOME}"/proxy_install.sh "${PROXY_HOME}" && \
    source /etc/profile && \
    dnf update -y && \
    dnf clean all -y && \
    dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    dnf install -y clamav clamav-update amavis perl-Digest-SHA1 perl-IO-stringy && \
    rm -f /etc/amavisd/amavisd.conf && \
    mkdir /target

ADD Configuration/Clamd /etc/clamd.d
ADD Configuration/Amavisd /etc
ADD Scripts/do_clam.sh /do_clam.sh
ADD Scripts/start.sh /start.sh
ADD Scripts/logrotate.sh /logrotate.sh

EXPOSE $MAIN_PORT

CMD sh start.sh "${MAIN_PORT}"