#!/bin/bash -e
# =====================================================================
# Build script running OpenNMS Sentinel in Docker environment
#
# Source: https://github.com/opennms-forge/docker-sentinel
# Web: https://www.opennms.org
#
# =====================================================================

# Error codes
E_ILLEGAL_ARGS=126

SENTINEL_OVERLAY_CFG=/opt/sentinel-overlay
KARAF_FEATURES_CFG="$SENTINEL_HOME"/etc/org.apache.karaf.features.cfg

# Help function used in error messages and -h option
usage() {
    echo ""
    echo "Docker entry script for OpenNMS Sentinel service container"
    echo ""
    echo "-c: Start Sentinel and use environment credentials to register Sentinel on OpenNMS."
    echo "    WARNING: Credentials can be exposed via docker inspect and log files. Please consider to use -s option."
    echo "-s: Initialize a keystore file with credentials in /keystore/scv.jce."
    echo "    Mount /keystore to your local system or a volume to save the keystore file."
    echo "    You can mount the keystore file to ${SENTINEL_HOME}/etc/scv.jce and just use -f to start the Sentinel."
    echo "-f: Initialize and start OpenNMS Sentinel in foreground."
    echo "-d: Same as -f, but starts the OpenNMS Sentinel in debug mode"
    echo "-h: Show this help."
    echo ""
}

useEnvCredentials(){
  echo "WARNING: Credentials can be exposed via docker inspect and log files. Please consider to use a keystore file."
  echo "         You can initialize a keystore file with the -s option."
  ${SENTINEL_HOME}/bin/scvcli set opennms.http ${OPENNMS_HTTP_USER} ${OPENNMS_HTTP_PASS}
  ${SENTINEL_HOME}/bin/scvcli set opennms.broker ${OPENNMS_BROKER_USER} ${OPENNMS_BROKER_PASS}
}

setCredentials() {
  # Directory to initialize a new keystore file which can be mounted to the local host
  if [ -z /keystore ]; then
    mkdir /keystore
  fi

  read -p "Enter OpenNMS HTTP username: " OPENNMS_HTTP_USER
  read -s -p "Enter OpenNMS HTTP password: " OPENNMS_HTTP_PASS
  echo ""

  read -p "Enter OpenNMS Broker username: " OPENNMS_BROKER_USER
  read -s -p "Enter OpenNMS Broker password: " OPENNMS_BROKER_PASS
  echo ""

  ${SENTINEL_HOME}/bin/scvcli set opennms.http ${OPENNMS_HTTP_USER} ${OPENNMS_HTTP_PASS}
  ${SENTINEL_HOME}/bin/scvcli set opennms.broker ${OPENNMS_BROKER_USER} ${OPENNMS_BROKER_PASS}

  cp ${SENTINEL_HOME}/etc/scv.jce /keystore
}

initConfig() {
    if [ ! -d ${SENTINEL_HOME} ]; then
        echo "OpenNMS Sentinel home directory doesn't exist in ${SENTINEL_HOME}."
        exit ${E_ILLEGAL_ARGS}
    fi

    if [ ! -f ${SENTINEL_HOME}/etc/configured} ]; then
        # Expose Karaf Shell
        sed -i "s,sshHost=127.0.0.1,sshHost=0.0.0.0," ${SENTINEL_HOME}/etc/org.apache.karaf.shell.cfg

        # Expose the RMI registry and server
        sed -i "s,rmiRegistryHost.*,rmiRegistryHost=0.0.0.0,g" ${SENTINEL_HOME}/etc/org.apache.karaf.management.cfg
        sed -i "s,rmiServerHost.*,rmiServerHost=0.0.0.0,g" ${SENTINEL_HOME}/etc/org.apache.karaf.management.cfg

	# Use the local repo
	sed -i 's|org.ops4j.pax.url.mvn.localRepository.*|#org.ops4j.pax.url.mvn.localRepository=|g' /opt/sentinel/etc/org.ops4j.pax.url.mvn.cfg

        # Set Sentinel location and connection to OpenNMS instance
        SENTINEL_CONFIG=${SENTINEL_HOME}/etc/org.opennms.sentinel.controller.cfg
        echo "location = ${SENTINEL_LOCATION}" > ${SENTINEL_CONFIG}
        echo "id = ${SENTINEL_ID:=$(uuidgen)}" >> ${SENTINEL_CONFIG}
        echo "broker-url = ${OPENNMS_BROKER_URL}" >> ${SENTINEL_CONFIG}
        echo "http-url = ${OPENNMS_HTTP_URL}" >> ${SENTINEL_CONFIG}

        # Configure datasource
        DB_CONFIG=${SENTINEL_HOME}/etc/org.opennms.netmgt.distributed.datasource.cfg
        echo "datasource.url = jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}" > ${DB_CONFIG}
        echo "datasource.username = ${POSTGRES_USER}" >> ${DB_CONFIG}
        echo "datasource.password = ${POSTGRES_PASSWORD}" >> ${DB_CONFIG}
        echo "datasource.databaseName = ${POSTGRES_DB}" >> ${DB_CONFIG}

        # Mark as configured
        echo "Configured $(date)" > ${SENTINEL_HOME}/etc/configured
    else
        echo "OpenNMS Sentinel is already configured, skipped."
    fi
}

applyOverlayConfig() {
  if [ -d "$SENTINEL_OVERLAY_CFG" -a -n "$(ls -A ${SENTINEL_OVERLAY_CFG})" ]; then
    echo "Apply custom configuration from ${SENTINEL_OVERLAY_CFG}."
    cp -r ${SENTINEL_OVERLAY_CFG}/* ${SENTINEL_HOME}/ || exit ${E_INIT_CONFIG}
  else
    echo "No custom config found in ${SENTINEL_OVERLAY_CFG}. Use default configuration."
  fi
}

updateKarafFeaturesConfig() {
  # Add any additional provided repositories to Karaf config
  if [ -n "$KARAF_REPOS" ]; then
    echo "Updating Karaf repositories"
    local repoReplaceText="# Add product repositories here"
    local repoPlaceholderLine=$(awk '/'"$repoReplaceText"'/{print NR}' "$KARAF_FEATURES_CFG")
    # Append a line continuation and comma to the line before the placeholder text
    sed -i $((repoPlaceholderLine - 1))'s/$/, \\/' "$KARAF_FEATURES_CFG"
    # Append the features to the featuresBoot by replacing the placeholder text
    sed -i 's/'"$repoReplaceText"'/'$(sed -e 's/[\/&]/\\&/g' <<< "${KARAF_REPOS// /}")'/' "$KARAF_FEATURES_CFG"
  fi
  
  # Add any additional provided boot features to Karaf config
  if [ -n "$KARAF_FEATURES" ]; then
    echo "Updating Karaf features"
    local featureReplaceText="# Add product features here"
    local featurePlaceholderLine=$(awk '/'"$featureReplaceText"'/{print NR}' "$KARAF_FEATURES_CFG")
    # Append a line continuation and comma to the line before the placeholder text
    sed -i $((featurePlaceholderLine - 1))'s/$/, \\/' "$KARAF_FEATURES_CFG"
    # Append the features to the featuresBoot by replacing the placeholder text
    sed -i 's/'"$featureReplaceText"'/'$(sed -e 's/[\/&]/\\&/g' <<< "${KARAF_FEATURES// /}")'/' "$KARAF_FEATURES_CFG"
  fi
}

applyKarafDebugLogging() {
  if [ -n "$KARAF_DEBUG_LOGGING" ]; then
    echo "Updating Karaf debug logging"
    for log in $(sed "s/,/ /g" <<< "$KARAF_DEBUG_LOGGING"); do
      logUnderscored=${log//./_}
      echo "log4j2.logger.${logUnderscored}.level = DEBUG" >> "$SENTINEL_HOME"/etc/org.ops4j.pax.logging.cfg
      echo "log4j2.logger.${logUnderscored}.name = $log" >> "$SENTINEL_HOME"/etc/org.ops4j.pax.logging.cfg
    done
  fi
}

configureKaraf() {
  updateKarafFeaturesConfig
  applyKarafDebugLogging
}

start() {
    cd ${SENTINEL_HOME}/bin
    ./karaf server ${SENTINEL_DEBUG}
}

# Evaluate arguments for build script.
if [[ "${#}" == 0 ]]; then
    usage
    exit ${E_ILLEGAL_ARGS}
fi

# Evaluate arguments for build script.
while getopts csdfh flag; do
    case ${flag} in
        c)
            useEnvCredentials
            initConfig
            applyOverlayConfig
            configureKaraf
            start
            ;;
        s)
            setCredentials
            applyOverlayConfig
            configureKaraf
            ;;
        d)
            SENTINEL_DEBUG="debug"
            initConfig
            applyOverlayConfig
            configureKaraf
            start
            ;;
        f)
            initConfig
            applyOverlayConfig
            configureKaraf
            start
            ;;
        h)
            usage
            exit
            ;;
        *)
            usage
            exit ${E_ILLEGAL_ARGS}
            ;;
    esac
done

# Strip of all remaining arguments
shift $((OPTIND - 1));

# Check if there are remaining arguments
if [[ "${#}" > 0 ]]; then
    echo "Error: Too many arguments: ${*}."
    usage
    exit ${E_ILLEGAL_ARGS}
fi
