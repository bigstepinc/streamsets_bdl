#!/bin/bash

# Start Zookeeper service
nohup $KAFKA_HOME/bin/zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties &

# Start Kafka service
$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties

