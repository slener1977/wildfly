FROM java:8-jre

# explicitly set user/group IDs
RUN groupadd -r wildfly --gid=1111 && useradd -r -g wildfly --uid=1111 wildfly

# grab gosu for easy step-down from root
RUN gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
RUN arch="$(dpkg --print-architecture)" \
    && set -x \
    && curl -o /usr/local/bin/gosu -fSL "https://github.com/tianon/gosu/releases/download/1.3/gosu-$arch" \
    && curl -o /usr/local/bin/gosu.asc -fSL "https://github.com/tianon/gosu/releases/download/1.3/gosu-$arch.asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu

ENV WILDFLY_VERSION=9.0.2.Final \
    KEYCLOAK_VERSION=1.7.0.Final \
    JBOSS_LOGMANAGER_EXT_VERSION=1.0.0.Alpha3 \
    JBOSS_LOGMANAGER_JAR=jboss-logmanager-ext-${JBOSS_LOGMANAGER_EXT_VERSION}.jar \
    JBOSS_HOME=/opt/wildfly \
    ADMIN_USER=admin \
    ADMIN_PASSWORD=admin

RUN cd $HOME \
    && curl https://download.jboss.org/wildfly/$WILDFLY_VERSION/wildfly-$WILDFLY_VERSION.tar.gz | tar xz \
    && mv $HOME/wildfly-$WILDFLY_VERSION $JBOSS_HOME \
    && curl http://downloads.jboss.org/keycloak/$KEYCLOAK_VERSION/keycloak-overlay-$KEYCLOAK_VERSION.tar.gz | tar xz -C $JBOSS_HOME \
    && curl http://downloads.jboss.org/keycloak/$KEYCLOAK_VERSION/adapters/keycloak-oidc/keycloak-wildfly-adapter-dist-$KEYCLOAK_VERSION.tar.gz | tar xz -C $JBOSS_HOME \
    && mkdir -p $JBOSS_HOME/modules/org/jboss/logmanager/ext/main \
    && curl http://repository.jboss.org/nexus/service/local/repositories/releases/content/org/jboss/logmanager/jboss-logmanager-ext/$JBOSS_LOGMANAGER_EXT_VERSION/$JBOSS_LOGMANAGER_JAR \
     -o $JBOSS_HOME/modules/org/jboss/logmanager/ext/main/$JBOSS_LOGMANAGER_JAR \
    && $JBOSS_HOME/bin/add-user.sh $ADMIN_USER $ADMIN_PASSWORD --silent \
    && chown -R wildfly:wildfly $JBOSS_HOME

COPY jboss-logmanager-ext-module.xml $JBOSS_HOME/modules/org/jboss/logmanager/ext/main/module.xml

# Default configuration: can be overridden at the docker command line
ENV JAVA_OPTS -Xms64m -Xmx512m -Djava.net.preferIPv4Stack=true -Djboss.modules.system.pkgs=org.jboss.byteman -Djava.awt.headless=true

# Ensure signals are forwarded to the JVM process correctly for graceful shutdown
ENV LAUNCH_JBOSS_IN_BACKGROUND true

ENV PATH $JBOSS_HOME/bin:$PATH

VOLUME $JBOSS_HOME/standalone
VOLUME $JBOSS_HOME/domain

 # Expose the ports we're interested in
EXPOSE 8080 9990

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["standalone.sh", "-b", "0.0.0.0", "-bmanagement", "0.0.0.0"]
