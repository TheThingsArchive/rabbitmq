# The Things Network RabbitMQ

RabbitMQ is open source message broker software (sometimes called message-oriented middleware) that implements the Advanced Message Queuing Protocol (AMQP). The RabbitMQ server is written in the Erlang programming language and is built on the Open Telecom Platform framework for clustering and failover. Client libraries to interface with the broker are available for all major programming languages.

## About this image

- Based on [`rabbitmq:management`](https://hub.docker.com/_/rabbitmq/)
- Includes `rabbitmq_mqtt` plugin

## Quick Start

- `docker-compose build`
- `docker-compose up`

## Usage

**Generating SSL Keys/Certs:**

This requires [cfssl](https://github.com/cloudflare/cfssl).

```
cd tls
./build.sh
```

**Admin without SSL:**

```
rabbitmqadmin list users
```

**Admin with SSL:**

```
rabbitmqadmin --ssl --ssl-ca-cert-file ./tls/ca.pem --ssl-key-file ./tls/client-key.pem --ssl-cert-file ./tls/client.pem --port 15671 list users
```

**MQTT without SSL:**

```
mosquitto_sub -d -t '#'
```

**MQTT with SSL:**

```
mosquitto_sub -p 8883 --cafile ./tls/ca.pem -d -t '#'
```

## Added Ports

- `1883` MQTT
- `8883` MQTT (SSL)

## Added Environment Variables

- `RABBITMQ_MQTT_VHOST`
- `RABBITMQ_MQTT_EXCHANGE`
- `RABBITMQ_MQTT_DEFAULT_USER`
- `RABBITMQ_MQTT_DEFAULT_PASS`
