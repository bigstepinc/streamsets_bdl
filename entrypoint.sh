#!/bin/bash

#Setup environment
ifconfig | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b" >> output
local_ip=$(head -n1 output)
rm output


echo "my local ip is $local_ip"

# Retrieve the instances in the Kafka cluster
mkdir /tmp/zookeeper && mkdir /tmp/kafka-logs

cd $KAFKA_HOME && \
cd ./config 
touch hosts

sleep 5
nslookup $HOSTNAME_ZOOKEEPER >> zk.cluster

echo "the zookeeper cluster is the following one"
cat zk.cluster

# Configure Zookeeper
NO=$(($(wc -l < zk.cluster) - 2))

while read line; do
	ip=$(echo $line | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")
	echo "$ip" >> zk.cluster.tmp
done < 'zk.cluster'
rm zk.cluster

sort -n zk.cluster.tmp > zk.cluster.tmp.sort
mv zk.cluster.tmp.sort zk.cluster.tmp

no_instances=1
while read line; do
        if [ "$line" != "" ]; then
		#eval var=\$"HOST"$no_instances
		myindex=$(echo $line | sed -e 's/\.//g')
		echo "server.$myindex=$line:2888:3888" >> $KAFKA_HOME/config/zookeeper.properties
		echo "$(cat hosts) $line:2181" >  hosts
		no_instances=$(($no_instances + 1))
	fi
done < 'zk.cluster.tmp'

index=0

nslookup $HOSTNAME_KAFKA >> kafka.cluster

NOK=$(($(wc -l < kafka.cluster) - 2))

echo "NOK is $NOK"
cat kafka.cluster


# Configure 
#NO=$(($(wc -l < kafka.cluster) - 2))

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
			#echo "$index" >> /tmp/zookeeper/myid
			current_index=$index
			echo "my current index is $current_index"
			cp $KAFKA_HOME/config/server.properties $KAFKA_HOME/config/server-$index.properties
			sed "s/broker.id=0/broker.id=$index/" $KAFKA_HOME/config/server-$index.properties >> $KAFKA_HOME/config/server-$index.properties.tmp
			mv $KAFKA_HOME/config/server-$index.properties.tmp $KAFKA_HOME/config/server-$index.properties
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

index=1

while [ $index -le $NOK ]; do
	echo "index is $index and current index is $current_index"
	if [ $index == $current_index ] ; then
		echo "modific acum zookeeper connect"
		sed "s/zookeeper.connect=localhost:2181/zookeeper.connect=$content/" $KAFKA_HOME/config/server-$index.properties >> $KAFKA_HOME/config/server-$index.properties.tmp && \
		mv  $KAFKA_HOME/config/server-$index.properties.tmp  $KAFKA_HOME/config/server-$index.properties

# Start Zookeeper service
#nohup $KAFKA_HOME/bin/zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties &

# Start Kafka service
		$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server-${index}.properties
	fi
	index=$(($index + 1))
done
