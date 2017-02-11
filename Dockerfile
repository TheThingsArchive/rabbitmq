FROM rabbitmq:management-alpine

RUN rabbitmq-plugins enable --offline rabbitmq_mqtt

EXPOSE 1883 8883

COPY docker-entrypoint.sh /usr/local/bin/
RUN chown rabbitmq /usr/local/bin/docker-entrypoint.sh
