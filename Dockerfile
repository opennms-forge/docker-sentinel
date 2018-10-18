FROM opennms/openjdk:latest

ARG SENTINEL_VERSION=branches-features-sentinel

ENV SENTINEL_HOME=/opt/sentinel

# TODO MVR SENTINEL_LOCATION is not used at the moment
ENV SENTINEL_ID=
ENV SENTINEL_LOCATION=SENTINEL

ENV OPENNMS_BROKER_URL=tcp://127.0.0.1:61616
ENV OPENNMS_HTTP_URL=http://127.0.0.1:8980/opennms

ENV OPENNMS_HTTP_USER minion
ENV OPENNMS_HTTP_PASS minion
ENV OPENNMS_BROKER_USER minion
ENV OPENNMS_BROKER_PASS minion

ENV POSTGRES_HOST=localhost
ENV POSTGRES_PORT=5432
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=
ENV POSTGRES_DB=opennms

RUN yum -y --setopt=tsflags=nodocs update && \
    rpm -Uvh http://yum.opennms.org/repofiles/opennms-repo-${SENTINEL_VERSION}-rhel7.noarch.rpm && \
    rpm --import http://yum.opennms.org/OPENNMS-GPG-KEY && \
    yum -y install opennms-sentinel && \
    yum clean all && \
    rm -rf /var/cache/yum && \
    chown -R sentinel:sentinel /opt/sentinel

USER sentinel

COPY ./entrypoint.sh /

VOLUME [ "/opt/sentinel/deploy", "/opt/sentinel/etc", "/opt/sentinel/data" ]

LABEL license="AGPLv3" \
      org.opennms.horizon.version="${SENTINEL_VERSION}" \
      vendor="OpenNMS Community" \
      name="Sentinel"

ENTRYPOINT [ "/entrypoint.sh" ]

CMD [ "-h" ]

##------------------------------------------------------------------------------
## EXPOSED PORTS
##------------------------------------------------------------------------------
## -- Sentinel Karaf Debug 5005/TCP
## -- Sentinel KARAF SSH   8301/TCP
EXPOSE 5005
EXPOSE 8301
