## Supported tags

* `bleeding`, daily bleeding edge version of Horizon Sentinel 25 using OpenJDK 11-jdk
* `24.0.0-1`, `latest` is a reference to last stable release of Horizon Sentinel using OpenJDK 11-jdk

## General Project Information

* CI/CD Status: [![CircleCI](https://circleci.com/gh/opennms-forge/docker-sentinel.svg?style=svg)](https://circleci.com/gh/opennms-forge/docker-sentinel)
* Container Image Info: [![](https://images.microbadger.com/badges/version/opennms/sentinel.svg)](https://microbadger.com/images/opennms/sentinel "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/opennms/sentinel.svg)](https://microbadger.com/images/opennms/sentinel "Get your own image badge on microbadger.com") [![](https://images.microbadger.com/badges/license/opennms/sentinel.svg)](https://microbadger.com/images/opennms/sentinel "Get your own license badge on microbadger.com")
* CI/CD System: [CircleCI]
* Docker Container Image Repository: [DockerHub]
* Issue- and Bug-Tracking: [GitHub issue]
* Source code: [GitHub]
* Chat: [IRC] or [Web Chat]
* Maintainer: ronny@opennms.org

## Sentinel Docker files

This repository provides OpenNMS Sentinels as docker images.

It is recommended to use `docker-compose` to build a service stack.
You can provide the Sentinel configuration in the `.sentinel.env` file.

## Requirements

* docker 18.05.0-ce, build 89658be
* docker-compose 1.21.1, build 5a3f1a3
* git
* optional on MacOSX, Docker environment, e.g. Kitematic, boot2docker or similar

## Usage

```
git clone https://github.com/opennms-forge/docker-sentinel.git
cd docker-sentinel
docker-compose up -d
```

The Karaf Shell is exposed on TCP port 8301

To start the Sentinel and initialize the configuration run with argument `-f`.

You can login with default user *admin* with password *admin*.
Please change immediately the default password to a secure password described in the [Install Guide].

## Basic Environment Variables

* `MINION_ID`, the Sentinel ID
* `MINION_LOCATION`, the Sentinel Location
* `OPENNMS_HTTP_URL`, the OpenNMS WebUI Base URL
* `OPENNMS_HTTP_USER`, the user name for the OpenNMS ReST API
* `OPENNMS_HTTP_PASS`, the password for the OpenNMS ReST API
* `OPENNMS_BROKER_URL`, the ActiveMQ URL
* `OPENNMS_BROKER_USER`, the username for ActiveMQ authentication
* `OPENNMS_BROKER_PASS`, the password for ActiveMQ authentication

## Advanced Environment Variables

Kafka and UDP listeners can be configured through environment variables.
All the valid configuration entries are valid and will be processed on demand, depending on a given environment variable prefix:

* `KAFKA_RPC_`, to denote a Kafka setting for RPC
* `KAFKA_SINK_`, to denote a Kafka setting for Sink
* `UDP_`, to denote a UDP listener

### Enable Kafka for RPC (requires Horizon 23 or newer)

A sample configuration would be:

```
KAFKA_RPC_BOOTSTRAP_SERVERS=kafka_server_01:9092
KAFKA_RPC_ACKS=1
```

The above will instruct the bootstrap script to create a file called `$MINION_HOME/etc/org.opennms.core.ipc.rpc.kafka.cfg` with the following content:

```
bootstrap.servers=kafka_server_01:9092
acks=1
```

As you can see, after the prefix, you specify the name of the variable, and the underscore character will be replaced with a dot.

### Enable Kafka for Sink

A sample configuration would be:

```
KAFKA_SINK_BOOTSTRAP_SERVERS=kafka_server_01:9092
```

A similar behavior happens to populate `$MINION_HOME/etc/org.opennms.core.ipc.sink.kafka.cfg`.

### UDP Listeners

In this case, the environment variable includes the UDP port, that will be used for the configuration file name, and the properties that follow the same behavor like Kafka.
For example:

```
UDP_50001_NAME=NX-OS
UDP_50001_CLASS_NAME=org.opennms.netmgt.telemetry.listeners.udp.UdpListener
UDP_50001_LISTENER_PORT=50001
UDP_50001_HOST=0.0.0.0
UDP_50001_MAX_PACKET_SIZE=16192
```

The above will instruct the bootstrap script to create a file called `$MINION_HOME/etc/org.opennms.features.telemetry.listeners-udp-50001.cfg` with the following content:

```
name=NXOS
class-name=org.opennms.netmgt.telemetry.listeners.udp.UdpListener
listener.port=50001
maxPacketSize=16192
```

Note: `CLASS_NAME` and `MAX_PACKET_SIZE` are special cases and will be translated properly.

## Run as root or non-root

By default, Sentinel will run using the default `sentinel` user (uid: 999, gid: 997). Fortunately, thanks to OpenJDK 11 and the `setcap` utility, it is possible to execute ICMP requests without requiring changes on kernel settings.

## Dealing with Credentials

To communicate with OpenNMS credentials for the message broker and the ReST API are required.
There are two options to set those credentials to communicate with OpenNMS.

***Option 1***: Set the credentials with an environment variable

It is possible to set communication credentials with environment variables and using the `-c` option for the entrypoint.

```
docker run --rm -d \
  -e "MINION_LOCATION=Apex-Office" \
  -e "OPENNMS_BROKER_URL=tcp://172.20.11.19:61616" \
  -e "OPENNMS_HTTP_URL=http://172.20.11.19:8980/opennms" \
  -e "OPENNMS_HTTP_USER=sentinel" \
  -e "OPENNMS_HTTP_PASS=sentinel" \
  -e "OPENNMS_BROKER_USER=sentinel" \
  -e "OPENNMS_BROKER_PASS=sentinel" \
  opennms/sentinel -c
```

*IMPORTANT:* Be aware these credentials can be exposed in log files and the `docker inspect` command.
               It is recommended to use an encrypted keystore file which is described in option 2.

***Option 2***: Initialize and use a keystore file

Credentials for the OpenNMS communication can be stored in an encrypted keystore file `scv.jce`.
It is possible to start a Sentinel with a given keystore file by using a file mount into the container like `-v path/to/scv.jce:/opt/sentinel/etc/scv.jce`.

You can initialize a keystore file on your local system using the `-s` option on the Sentinel container using the interactive mode.

The following example creates a new keystore file `scv.jce` in your current working directory:

```
docker run --rm -it -v $(pwd):/keystore opennms/sentinel -s

Enter OpenNMS HTTP username: mysentinel
Enter OpenNMS HTTP password:
Enter OpenNMS Broker username: mysentinel
Enter OpenNMS Broker password:
[main] INFO org.opennms.features.scv.jceks.JCEKSSecureCredentialsVault - No existing keystore found at: {}. Using empty keystore.
[main] INFO org.opennms.features.scv.jceks.JCEKSSecureCredentialsVault - Loading existing keystore from: scv.jce
```

The keystore file can be used by mounting the file into the container and start the Sentinel application with `-f`.

```
docker run --rm -d \
  -e "OPENNMS_BROKER_URL=tcp://opennms:61616"
  -e "OPENNMS_HTTP_URL=http://opennms:8980/opennms"
  -e "POSTGRES_DB=opennms"
  -v $(pwd)/auto-deploy/features-jms.xml:/opt/sentinel/deploy/features-jms.xml
  opennms/sentinel
```

## Using etc-overlay for custom configuration

If you just want to maintain custom configuration files outside of Sentinel, you can use an etc-overlay directory.
All files in this directory are just copied into /opt/sentinel/etc in the running container.
You can just mount a local directory like this:

```yml
volumes:
  - ./etc-overlay:/opt/sentinel-etc-overlay
```

## Support and Issues

Please open issues in the [GitHub issue](https://github.com/opennms-forge/docker-sentinel) section.

[GitHub]: https://github.com/opennms-forge/docker-sentinel.git
[DockerHub]: https://hub.docker.com/r/opennms/sentinel
[GitHub issue]: https://github.com/opennms-forge/docker-sentinel
[CircleCI]: https://circleci.com/gh/opennms-forge/docker-sentinel
[Web Chat]: https://chats.opennms.org/opennms-discuss
[IRC]: irc://freenode.org/#opennms
