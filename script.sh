#!/bin/bash

# Retrieve the instances in the Kafka cluster
mkdir /tmp/zookeeper && mkdir /tmp/kafka-logs

cd $KAFKA_HOME && \
cd ./config && \
sleep 100 && \
nslookup $HOSTNAME >>kafka.cluster

# Configure Zookeeper
no_instances=$(($(wc -l < kafka.cluster) - 2))

while [ $no_instances -le $NO ] ; do
	rm -rf $KAFKA_HOME/config/kafka.cluster
	nslookup $HOSTNAME >>kafka.cluster
	no_instances=$(($(wc -l < kafka.cluster) - 2))
done

# Determine the local ip
ifconfig | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b" >> output
local_ip=$(head -n1 output) && \
rm output



touch hosts

while read line; do
		ip=$(echo $line | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")
		index=$(echo $line | grep -oE "Address [0-9]*:" | grep -oE "[0-9]*")
                index=$(($index + 0))
		if [ "$index" -le "$no_instances" ] && [ "$index" -gt "0" ]; then
			echo "server.$index=$ip:2888:3888" >> $KAFKA_HOME/config/zookeeper.properties
			echo "$(cat hosts) $ip:2181" >  hosts
		fi
		if [ "$ip" == "$local_ip" ]; then
			echo "$index" >> /tmp/zookeeper/myid
			#index=$(($index -1))
			sed "s/broker.id=0/broker.id=$index/" $KAFKA_HOME/config/server.properties >> $KAFKA_HOME/config/server.properties.tmp
                        mv $KAFKA_HOME/config/server.properties.tmp $KAFKA_HOME/config/server.properties
		fi
done < 'kafka.cluster' 
echo "initLimit=5" >> $KAFKA_HOME/config/zookeeper.properties
echo "syncLimit=2" >> $KAFKA_HOME/config/zookeeper.properties

#Remove kafka.cluster file
#rm -rf kafka.cluster

# configure all the hosts in the cluster in the server.properties file
sed -i 's/^ *//' hosts 
sed -e 's/\s/,/g' hosts > hosts.txt
#rm -rf hosts

content=$(cat $KAFKA_HOME/config/hosts.txt)

sed "s/zookeeper.connect=localhost:2181/zookeeper.connect=$content/" $KAFKA_HOME/config/server.properties >> $KAFKA_HOME/config/server.properties.tmp && \
mv  $KAFKA_HOME/config/server.properties.tmp  $KAFKA_HOME/config/server.properties
#rm -rf hosts.txt
