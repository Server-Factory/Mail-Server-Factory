#!/bin/sh

dbPort=5432
dovecotSaslPort=12345
dovecotLmtpPort=12346
postfixLog=/var/log/postfix.start.log
echo "Starting Postfix on `hostname`" > ${postfixLog}

echo "Checking database port: $dbPort" >> ${postfixLog}
if echo "^C" | telnet postgres_database ${dbPort} | grep "Connected"
then
    echo "Database process is bound to port: $dbPort" >> ${postfixLog}
else
   echo "No process bound to port: $dbPort" >> ${postfixLog}
   exit 1
fi

echo "Checking Dovecot SASL port: $dovecotSaslPort" >> ${postfixLog}
if echo "^C" | telnet dovecot_service ${dovecotSaslPort} | grep "Connected"
then
    echo "Dovecot process is bound to port: $dovecotSaslPort" >> ${postfixLog}
else
   echo "No process bound to port: $dovecotSaslPort" >> ${postfixLog}
   exit 1
fi

echo "Checking Dovecot LMTP port: $dovecotLmtpPort" >> ${postfixLog}
if echo "^C" | telnet dovecot_service ${dovecotLmtpPort} | grep "Connected"
then
    echo "Dovecot process is bound to port: $dovecotLmtpPort" >> ${postfixLog}
else
   echo "No process bound to port: $dovecotLmtpPort" >> ${postfixLog}
   exit 1
fi

postfix set-permissions >> ${postfixLog}
newaliases
postfix check >> ${postfixLog}
postfix start >> ${postfixLog}
if postfix status >> ${postfixLog}
then

    ports=(465 587)
    for port in ${ports[@]}; do
        if echo "^C" | telnet 127.0.0.1 ${port} | grep "Connected"
        then
            echo "Postfix is listening on port: $port" >> ${postfixLog}
        else
            echo "Postfix is not bound to port: $port" >> ${postfixLog}
            exit 1
        fi
    done

    tail -f ${postfixLog}
else
    exit 1
fi