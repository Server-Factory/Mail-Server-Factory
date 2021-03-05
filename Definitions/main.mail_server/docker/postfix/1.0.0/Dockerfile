FROM fedora:33

ARG DB_NAME
ARG AV_NAME
ARG DB_PORT
ARG AV_PORT
ARG AV_PORT_MAIL_SEND
ARG SERVICE_RECEIVE
ARG UTILS_HOME
ARG PROXY_HOME
ARG FACTORY_SERVICE
ARG proxy_host_ip

ENV AV_NAME "$AV_NAME"
ENV DB_NAME "$DB_NAME"
ENV DB_PORT "$DB_PORT"
ENV AV_PORT "$AV_PORT"
ENV AV_PORT_MAIL_SEND "$AV_PORT_MAIL_SEND"
ENV SERVICE_RECEIVE "$SERVICE_RECEIVE"
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
    dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    dnf install -y postfix postfix-pgsql && \
    alternatives --set mta /usr/sbin/sendmail.postfix && \
    groupadd -g 5000 vmail && useradd -g vmail -u 5000 vmail -d /home/vmail -m

ADD Configuration/*.* /etc/postfix/
ADD Scripts/start.sh /start.sh
ADD Scripts/logrotate.sh /logrotate.sh

EXPOSE 465

CMD sh "${UTILS_HOME}"/proxy_update_docker.sh "${PROXY_HOME}" && \
    sh start.sh "${DB_PORT}" "${AV_PORT}" "${DB_NAME}" "${AV_NAME}" "${SERVICE_RECEIVE}" "${AV_PORT_MAIL_SEND}"