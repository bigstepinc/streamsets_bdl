#!/bin/bash

#Setup environment
ifconfig | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b" >> output
local_ip=$(head -n1 output)
rm output

# Retrieve the instances in the Kafka cluster
mkdir /tmp/zookeeper && mkdir /tmp/kafka-logs

cd $KAFKA_HOME && \
cd ./config 
touch hosts

sleep 5
nslookup $HOSTNAME_ZOOKEEPER >> zk.cluster

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
		myindex=$(echo $line | sed -e 's/\.//g')
		echo "server.$myindex=$line:2888:3888" >> $KAFKA_HOME/config/zookeeper.properties
		echo "$(cat hosts) $line:2181" >  hosts
		no_instances=$(($no_instances + 1))
	fi
done < 'zk.cluster.tmp'

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
			###current_index=$index
			###echo "my current index is $current_index"
			oct3=$(echo $line | tr "." " " | awk '{ print $3 }')
			oct4=$(echo $line | tr "." " " | awk '{ print $4 }')
			index=$oct3$oct4
			current_index=$index
			cp $KAFKA_HOME/config/server.properties $KAFKA_HOME/config/server-$index.properties
			sed "s/broker.id=0/broker.id=$index/" $KAFKA_HOME/config/server-$index.properties >> $KAFKA_HOME/config/server-$index.properties.tmp
			mv $KAFKA_HOME/config/server-$index.properties.tmp $KAFKA_HOME/config/server-$index.properties
		else
			index=$(($index + 1))
		fi
	fi
done < 'kafka.cluster.tmp'

# configure all the hosts in the cluster in the server.properties file
sed -i 's/^ *//' hosts 
sed -e 's/\s/,/g' hosts > hosts.txt

content=$(cat $KAFKA_HOME/config/hosts.txt)

rm hosts.txt

touch hosts 

if [ "$HOSTNAME_ZOOKEEPER" != "" ]; then
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
			echo "$(cat hosts) $line:2181" >  hosts
			no_instances=$(($no_instances + 1))
		fi
	done < 'zk.cluster.tmp'

fi

sed -i 's/^ *//' hosts 
sed -e 's/\s/,/g' hosts > hosts.txt

content=$(cat hosts.txt)
ZKHOSTS=$content

rm hosts
rm hosts.txt

while read line; do
	
	oct3=$(echo $line | tr "." " " | awk '{ print $3 }')
	oct4=$(echo $line | tr "." " " | awk '{ print $4 }')
	index=$oct3$oct4
	
	if [ "$index" == "$current_index" ] ; then
		sed "s/zookeeper.connect=localhost:2181/zookeeper.connect=$content/" $KAFKA_HOME/config/server-$index.properties >> $KAFKA_HOME/config/server-$index.properties.tmp && \
		mv  $KAFKA_HOME/config/server-$index.properties.tmp  $KAFKA_HOME/config/server-$index.properties
		
		if [ "$KAFKA_PATH" != "" ]; then
			path1=$(echo $KAFKA_PATH | tr "\\" " " | awk '{ print $1 }')
			path2=$(echo $KAFKA_PATH | tr "\\" " " | awk '{ print $2 }')
			path3=$(echo $KAFKA_PATH | tr "\\" " " | awk '{ print $3 }')
			path=$path1$path2$path3
			cd $path && mkdir kafka-logs-$HOSTNAME_KAFKA
			sed "s/log.dirs.*/log.dirs=$KAFKA_PATH\/kafka-logs-$HOSTNAME_KAFKA/"  $KAFKA_HOME/config/server-$index.properties >>  $KAFKA_HOME/config/server-$index.properties.tmp &&
        		mv  $KAFKA_HOME/config/server-$index.properties.tmp  $KAFKA_HOME/config/server-$index.properties
		fi
		
		path=$path"/.lock"
		rm $path

		# Start Kafka Manager Service
		$KAFKA_MANAGER_HOME/bin/kafka-manager -Dkafka-manager.zkhosts=$ZKHOSTS > /dev/null &

		# Start Kafka servicE
		$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server-${index}.properties
	fi
done < 'kafka.cluster.tmp'
