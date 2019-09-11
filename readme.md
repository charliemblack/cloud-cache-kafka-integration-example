# Summary

In this project I show a sample integration between Pivotal Cloud Cache and Apache Kafka.    

Cloud Cache is a high performance key value data store powered by Apache Geode.   At Geode's heart is a rich eventing system.   That eventing system allows developer to build rich event driven applications.

We are going to use this event driven architecture to empower change data capture and forward those data events to Kafka.  In this example I am going to be using Geode's ``AsyncEventListener`` to asynchronously send data to Kafka so Geode data operations can continue to work at in memory speeds.

# How to deploy the Geode Kafka Integration to Pivotal Cloud Cache

The script below shows how connect to a Cloud Cache system and deploy code allow change data capture to be emitted to Kafka.

```shell script
gfsh
connect --url=https://cloudcache-url/gemfire/v1 --user=username --password=password
deploy --dir=kafka-geode-integration/build/dependancies
y
deploy --dir=kafka-geode-integration/build/libs
y
create async-event-queue --id=kafka-queue --listener=example.geode.kafka.KafkaAsyncEventListener --listener-param=bootstrap.servers#somekafkahost:9092 --batch-size=5 --batch-time-interval=1000
create region --name=test --type=PARTITION --async-event-queue-id=kafka-queue
```
# Deploy the Data Driver

The data driver for this project is a rest service with one method - `createCustomers`.    This method will create as many customers as the `count` argument that is passed in.

```shell script
cd <clone>/data-driver
cf push
```
# Example Output from Kafka

In Geode's `AsyncEventListener` we converted the `Customer` plain ole java object to JSON.      We then publish that JSON document on to a Kafka topic.   

To start the data flow we use `Driver` service that we deployed to PCF.   That service takes an argument and starts to create customers based on the `count` of customers passed in.   In the below code snippet we ask the service to push 5 customers into the system.

```$bash
curl -X GET \
  'http://mypcf-url:8080/createCustomers?count=5' 
```

Start up a kafka listener somewhere - kafka has a console consumer lets use that for now.

```
demo@demo-kafka:~/kafka_2.11-1.0.0$ bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test  
{
  "guid" : "b4af31db-f129-4437-b315-60ef72ce1968",
  "firstName" : "Alexis",
  "middleName" : "",
  "lastName" : "Spencer",
  "email" : "alexisspencer@gmail.com",
  "username" : "alexiss",
  "password" : "HM6vLlQS",
  "telephoneNumber" : "924-101-3682",
  "dateOfBirth" : "2003-01-23T16:52:40.757-08:00",
  "age" : 14,
  "companyEmail" : "alexis.spencer@datastore.biz",
  "nationalIdentityCardNumber" : "026-22-2967",
  "nationalIdentificationNumber" : "",
  "passportNumber" : "6kuqL2tq9"
}
...

```

# Running local

Its common practice to run everything locally before pushing our application to PCF.    With Cloud Cache its no different.    Just download the same version of GemFire as cloud cache packages, you can find out which version of GemFire it pacakges in the cloud cache readme which is typically hosted here: https://docs.pivotal.io/p-cloud-cache/1-8/release-notes.html

Since security is turned on in Cloud Cache I have created some scripts to launch GemFire with security turned on.   While its not the same security implementation it will give you some practice with working with a secured environment.    

For this project we are using spring boot data GemFire which does all of the heavy lifting for us for security.    You can see how the security is configured by looking at the [application.yml](data-driver/src/main/resources/application.yml)

From there we can see how the `dev` profile will inject a user name and password.   

In the `scripts` directory I have included some basic scripts to launch GemFire.   The script will launch one locator and two cache servers.

We can also optionally deploy or not deploy the Kafka integration. 

## Start GemFire for local testing

```shell script
cd <clone>/scripts
./start_gemfire.sh
```

## Start the Spring Boot Data Driver
```shell script
cd <clone>/data-driver
java -jar build/libs/data-driver-0.0.1-SNAPSHOT.jar
```

## Play in some data
```shell script
curl -X GET \
  'http://localhost:8080/createCustomers?count=5' 
```
## Deploy the kafka integration

```shell script
gfsh>connect --locator=localhost[10334] --security-properties-file=<clone>/config/gfsecurity.properties
gfsh>deploy --dir=kafka-geode-integration/build/libs

Deploying files: kafka-geode-integration-0.0.1-SNAPSHOT.jar
Total file size is: 0.00MB

Continue?  (Y/n): y
Member  |                Deployed JAR                | Deployed JAR Location
------- | ------------------------------------------ | -----------------------------------------------------------------------------------------------------------------------------------
server1 | kafka-geode-integration-0.0.1-SNAPSHOT.jar | /Users/cblack/dev/projects/samples/cloud-cache-kafka-integration-example/data/server1/kafka-geode-integration-0.0.1-SNAPSHOT.v1.jar
server2 | kafka-geode-integration-0.0.1-SNAPSHOT.jar | /Users/cblack/dev/projects/samples/cloud-cache-kafka-integration-example/data/server2/kafka-geode-integration-0.0.1-SNAPSHOT.v1.jar

gfsh>deploy --dir=kafka-geode-integration/build/dependancies

Deploying files: snappy-java-1.1.4.jar, kafka-clients-1.0.0.jar, lz4-java-1.4.jar
Total file size is: 3.31MB

Continue?  (Y/n): y
Member  |      Deployed JAR       | Deployed JAR Location
------- | ----------------------- | ----------------------------------------------------------------------------------------------------------------
server1 | snappy-java-1.1.4.jar   | /Users/cblack/dev/projects/samples/cloud-cache-kafka-integration-example/data/server1/snappy-java-1.1.4.v1.jar
server1 | kafka-clients-1.0.0.jar | /Users/cblack/dev/projects/samples/cloud-cache-kafka-integration-example/data/server1/lz4-java-1.4.v1.jar
server1 | lz4-java-1.4.jar        | /Users/cblack/dev/projects/samples/cloud-cache-kafka-integration-example/data/server1/kafka-clients-1.0.0.v1.jar
server2 | snappy-java-1.1.4.jar   | /Users/cblack/dev/projects/samples/cloud-cache-kafka-integration-example/data/server2/snappy-java-1.1.4.v1.jar
server2 | kafka-clients-1.0.0.jar | /Users/cblack/dev/projects/samples/cloud-cache-kafka-integration-example/data/server2/lz4-java-1.4.v1.jar
server2 | lz4-java-1.4.jar        | /Users/cblack/dev/projects/samples/cloud-cache-kafka-integration-example/data/server2/kafka-clients-1.0.0.v1.jar

gfsh>create async-event-queue --id=kafka-queue --listener=example.geode.kafka.KafkaAsyncEventListener --listener-param=bootstrap.servers#somekafkahost:9092 --batch-size=5 --batch-time-interval=1000
gfsh>alter region --name=/test --async-event-queue-id=kafka-queue

```
## Word of caution with Kafka Integration

The Kafka client will hang if the network doesn't work.    This means when you create the aync event queue and Kafka doesn't work or the route to the host doesn't exist the GFSH command will not return in a timely fashion.   GFSH will ultimately time out - but that thread is stuck on the server.    Since Cloud Cache doesn't offer a `restart` you will have to destroy and recreate the instance if you want a pristine server.





