#!/bin/bash

# Setup environment
# Determine the private ip of the container
ifconfig | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b" >> output
local_ip=$(head -n1 output)
rm output

# Retrieve the instances in the Kafka cluster
mkdir /tmp/zookeeper && mkdir /tmp/kafka-logs

cd $KAFKA_HOME && \
cd ./config 

# Retrive Zookeeper cluster configuration
touch hosts
sleep 5
nslookup $HOSTNAME_ZOOKEEPER >> zk.cluster

NO=$(($(wc -l < zk.cluster) - 2))

while read line; do
	ip=$(echo $line | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")
	echo "$ip" >> zk.cluster.tmp
done < 'zk.cluster'
rm zk.cluster

sort -n zk.cluster.tmp > zk.cluster.tmp.sort
mv zk.cluster.tmp.sort zk.cluster.tmp

# Configure zookeeper fields from the Kafka cluster
no_instances=1
while read line; do
        if [ "$line" != "" ]; then
		myindex=$(echo $line | sed -e 's/\.//g')
		echo "server.$myindex=$line:2888:3888" >> $KAFKA_HOME/config/zookeeper.properties
		echo "$(cat hosts) $line:2181" >  hosts
		no_instances=$(($no_instances + 1))
	fi
done < 'zk.cluster.tmp'
rm zk.cluster.tmp

# Retrive the components of the Kafka Cluster
index=0
nslookup $HOSTNAME_KAFKA >> kafka.cluster

NOK=$(($(wc -l < kafka.cluster) - 2))

while read line; do
	ip=$(echo $line | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")
	echo "$ip" >> kafka.cluster.tmp
done < 'kafka.cluster'
rm kafka.cluster

sort -n kafka.cluster.tmp > kafka.cluster.tmp.sort
mv kafka.cluster.tmp.sort kafka.cluster.tmp

index=1

while read line; do
	if [ "$line" != "" ]; then
		if [ "$line" == "$local_ip" ]; then
			current_index=$index
			cp $KAFKA_HOME/config/server.properties $KAFKA_HOME/config/server-$current_index.properties
			sed "s/broker.id=0/broker.id=$index/" $KAFKA_HOME/config/server-$current_index.properties >> $KAFKA_HOME/config/server-$current_index.properties.tmp
			mv $KAFKA_HOME/config/server-$current_index.properties.tmp $KAFKA_HOME/config/server-$current_index.properties
		else
			index=$(($index + 1))
		fi
	fi
done < 'kafka.cluster.tmp'
rm kafka.cluster.tmp


# configure all the hosts in the cluster in the server.properties file
sed -i 's/^ *//' hosts 
sed -e 's/\s/,/g' hosts > hosts.txt

content=$(cat $KAFKA_HOME/config/hosts.txt)

sed "s/zookeeper.connect=localhost:2181/zookeeper.connect=$content/" $KAFKA_HOME/config/server-$current_index.properties >> $KAFKA_HOME/config/server-$current_index.properties.tmp && \
mv  $KAFKA_HOME/config/server-$current_index.properties.tmp  $KAFKA_HOME/config/server-$current_index.properties
rm hosts

# Start Kafka Manager Service
ZKHOSTS=$content
$KAFKA_MANAGER_HOME/bin/kafka-manager -Dkafka-manager.zkhosts=$ZKHOSTS > /dev/null &

# Start Kafka service
$KAFKA_HOME/bin/kafka-server-start.sh -daemon $KAFKA_HOME/config/server-${current_index}.properties
