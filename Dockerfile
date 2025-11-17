FROM rabbitmq:3.12-management-alpine

COPY rabbitmq.conf /etc/rabbitmq/rabbitmq.conf
COPY definitions.json /etc/rabbitmq/definitions.json

EXPOSE 5672 15672
