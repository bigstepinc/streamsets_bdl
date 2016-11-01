#!/bin/bash

#Setup environment
#cd /opt && bash /opt/script.sh
#rm /opt/script.sh


# Retrieve the instances in the Kafka cluster
mkdir /tmp/zookeeper && mkdir /tmp/kafka-logs

cd $KAFKA_HOME && \
cd ./config 

no_instances=1
while [ $no_instances -le $NO ] ; do
        eval var=\$"HOST"$no_instances
	echo "server.$no_instances=$val:2888:3888" >> $KAFKA_HOME/config/zookeeper.properties
	echo "$(cat hosts) $val:2181" >  hosts
done

echo "$index" >> /tmp/zookeeper/myid
sed "s/broker.id=0/broker.id=$index/" $KAFKA_HOME/config/server.properties >> $KAFKA_HOME/config/server.properties.tmp
mv $KAFKA_HOME/config/server.properties.tmp $KAFKA_HOME/config/server.properties
 
echo "initLimit=5" >> $KAFKA_HOME/config/zookeeper.properties
echo "syncLimit=2" >> $KAFKA_HOME/config/zookeeper.properties

# configure all the hosts in the cluster in the server.properties file
sed -i 's/^ *//' hosts 
sed -e 's/\s/,/g' hosts > hosts.txt

content=$(cat $KAFKA_HOME/config/hosts.txt)

sed "s/zookeeper.connect=localhost:2181/zookeeper.connect=$content/" $KAFKA_HOME/config/server.properties >> $KAFKA_HOME/config/server.properties.tmp && \
mv  $KAFKA_HOME/config/server.properties.tmp  $KAFKA_HOME/config/server.properties

# Start Zookeeper service
nohup $KAFKA_HOME/bin/zookeeper-server-start.sh $KAFKA_HOME/config/zookeeper.properties &

# Start Kafka service
$KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties
