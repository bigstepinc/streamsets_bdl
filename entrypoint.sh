#!/bin/bash

# Retrieve the instances in the Kafka cluster
cd $KAFKA_HOME && \
cd ./config && \
nslookup $HOSTNAME >>kafka.cluster

# Configure Zookeeper
no_instances=$(($(wc -l < kafka.cluster) - 2))

while read line; do
		ip=$(echo $line | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")
		index=$(echo $line | grep -oE "Address [0-9]*:" | grep -oE "[0-9]*")
                index=$(($index + 0))
		if [ "$index" -le "$no_instances" ] && [ "$index" -gt "0" ]; then
			echo "server.$index=$ip:2888:3888" >> /opt/kafka/config/zookeeper.properties
		fi
done < 'kafka.cluster'

#Remove kafka.cluster file
rm -rf kafka.cluster


