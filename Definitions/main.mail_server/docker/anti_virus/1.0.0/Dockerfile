FROM fedora:33

ADD $UTILS_HOME /Utils

RUN dnf update -y && \
    dnf clean all -y && \
    dnf install findutils -y && \
    dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    dnf install -y clamav clamav-update amavis perl-Digest-SHA1 perl-IO-stringy telnet net-tools iputils && \
    rm -f /etc/amavisd/amavisd.conf && \
    mkdir /target

ADD Configuration/Clamd /etc/clamd.d
ADD Configuration/Amavisd /etc
ADD Scripts/do_clam.sh /do_clam.sh
ADD Scripts/start.sh /start.sh
ADD Scripts/logrotate.sh /logrotate.sh

EXPOSE $MAIN_PORT

CMD sh start.sh "${MAIN_PORT}"