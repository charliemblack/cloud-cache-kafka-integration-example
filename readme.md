# Summary

In this project I show a integration between GemFire and Apache Kafka.    

GemFire is a high performance key value data store.   At GemFire's core is a rich eventing system.   That eventing system allows developer to build rich event driven applications.   This project just scratches the surface with what is possible with integrating with kafka.   We could layer on some Enterprise Integration Patterns and rules engine and build extremely powerful realtime architectures. 

In this project we are going to use this event driven capabilities to empower change data capture pattern.    The goal is to forward those data events to Kafka.  This example uses GemFire's `AsyncEventListener` to asynchronously send data to Kafka so GemFire data operations can continue to work at in memory speeds.

`AsyncEventListener` has the added bonus of allowing the system architect to use bulk operations.   This will help with slower disk based architectures.   `AsyncEventListener` can batch up requests based on time or number of events, whichever comes first.   

Another bonus to `AsyncEventListener`s is the parallelism that can be achieved - not only is each server handling its partition of the load, a given server can further partition its work load.   So we get horizontal and vertical scaling with `AsyncEventListener`.   If you are familiar with competing consumer pattern - `AsyncEventListener` provides that capability in a durable and fault-tolerant manner.

Check out the [AsyncEventListener listener implementation](kafka-GemFire-integration/src/main/java/example/GemFire/kafka/KafkaAsyncEventListener.java)

# How Build

This project uses gradle and has two projects.

## Data Driver Project

The Data Driver project is a spring boot rest service.   The service has one method `createCustomers` which takes a count.   That count will be the number of auto generated `Customers` it creates and stores in GemFire.

It was designed to be run locally or easily pushed to Cloud Foundry.   If you are pushing to cloud foundry you may be interested in the [application manifest](data-driver/manifest.yml).

## Kafka GemFire Integration

This project contains the implementation - its a single class [KafkaAsyncEventListener.java](kafka-GemFire-integration/src/main/java/example/GemFire/kafka/KafkaAsyncEventListener.java).   The bulk of the class is just boilerplate code enabling the injection of Kafka connection information.  The good part where we transform the data pass the data to Kafka is contained in the `processEvents` method.

In the `processEvents` method we transform our datamodel into JSON and send those events to Kafka.

## Building

This project is working with two models of running code, uber jar (spring boot) and standard jars.   So we need to build both.
 
```java
cd <clone>
./gradlew clean jar bootJar
```

# How to deploy the GemFire Kafka Integration to GemFire

GemFire is an always on solution - just go create a service instance.   

The script below shows how connect to a GemFire system and deploy code allow change data capture to be emitted to Kafka.   To get your connection details check out the output from [cf service-key](https://docs.cloudfoundry.org/devguide/services/service-keys.html).

In this example I have a `cloudcache-dev` service and its service key is called `cloudcache-key` 

```shell script
cf service-key cloudcache-dev cloudcache-key
```

## Script to create async queue and deploy our implementation and bind the queue to a region
```shell script

gfsh
connect --url=https://cloudcache-url/gemfire/v1 --user=username --password=password
deploy --dir=kafka-GemFire-integration/build/dependancies
y
deploy --dir=kafka-GemFire-integration/build/libs
y
create async-event-queue --id=kafka-queue --listener=example.GemFire.kafka.KafkaAsyncEventListener --listener-param=bootstrap.servers#somekafkahost:9092 --batch-size=5 --batch-time-interval=1000
create region --name=test --type=PARTITION --async-event-queue-id=kafka-queue
```
# Deploy the Data Driver

The data driver for this project is a rest service with one method - `createCustomers`.    This method will create as many customers as the `count` argument that is passed in.

```shell script
cd <clone>/data-driver
cf push
```
# Example Output from Kafka

Start up a kafka listener somewhere - kafka has a console consumer lets use that for now.

```
demo@demo-kafka:~/kafka_2.11-1.0.0$ bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test  
```

To start the data flowing we use `Driver` service that we deployed to PCF.   That service takes an argument and starts to create customers based on the `count` of customers passed in.   In the below code snippet we ask the service to push 5 customers into the system.

```$bash
curl -X GET \
  'http://mypcf-url:8080/createCustomers?count=5' 
```

Take a look at the kafka listener - some events should start flowing once we hit the policy we set - either 5 items or 1 second.

```
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

Its common practice to run everything locally before pushing our application to PCF.    With GemFire its no different.    Just download the same version of GemFire as GemFire packages, you can find out which version of GemFire it packages in the GemFire readme : https://docs.pivotal.io/p-cloud-cache/1-8/release-notes.html

Since authorization is turned on by default in GemFire, I have created some scripts to launch GemFire with authorization turned on.   While its not the same authorization implementation it will give you some practice with working with a secured environment.    

You can see how the security is configured by looking at the [application.yml](data-driver/src/main/resources/application.yml)

From there we can see how the `dev` profile will inject a user name and password.   However for the cloud environement all of the authorization details are injected into the application through the environment.    Spring Boot Data GemFire helps us with that.

In the `scripts` directory I have included some basic scripts to launch GemFire.   The script will launch one locator and two cache servers.

We can also optionally deploy or not deploy the Kafka integration.   In this "script" I will go with the idea that we are leaving the kafka integration to last moment.    This would mimic how easy it is to add change data capture to a GemFire architecture.

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
**Note:** This data will not be in the queue for kafka since we haven't told GemFire about the integration.
 
## Deploy the kafka integration

```shell script
gfsh>connect --locator=localhost[10334] --security-properties-file=<clone>/config/gfsecurity.properties
gfsh>deploy --dir=kafka-GemFire-integration/build/libs

Deploying files: kafka-GemFire-integration-0.0.1-SNAPSHOT.jar
Total file size is: 0.00MB

Continue?  (Y/n): y
Member  |                Deployed JAR                | Deployed JAR Location
------- | ------------------------------------------ | -----------------------------------------------------------------------------------------------------------------------------------
server1 | kafka-GemFire-integration-0.0.1-SNAPSHOT.jar | /Users/cblack/dev/projects/samples/cloud-cache-kafka-integration-example/data/server1/kafka-GemFire-integration-0.0.1-SNAPSHOT.v1.jar
server2 | kafka-GemFire-integration-0.0.1-SNAPSHOT.jar | /Users/cblack/dev/projects/samples/cloud-cache-kafka-integration-example/data/server2/kafka-GemFire-integration-0.0.1-SNAPSHOT.v1.jar

gfsh>deploy --dir=kafka-GemFire-integration/build/dependancies

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

gfsh>create async-event-queue --id=kafka-queue --listener=example.GemFire.kafka.KafkaAsyncEventListener --listener-param=bootstrap.servers#somekafkahost:9092 --batch-size=5 --batch-time-interval=1000
gfsh>alter region --name=/test --async-event-queue-id=kafka-queue

```
All future events will be sent out over Kafka.

# Word of caution with Kafka 

The **Kafka Client** will hang if the something on the network doesn't work.    This means when you create the aync event queue and Kafka doesn't work or the route to the host doesn't exist the GFSH command will not return in a timely fashion.  GFSH will ultimately time out - but that thread is stuck on the server waiting for Kafka todo something.    Since GemFire doesn't offer a `restart` you will have to destroy and recreate the instance if you want a pristine server.

If you would like to make it so the gfsh command always returns in a timely manner - allow the `public void init(Properties props)` to return fast by running the initialization in a background thread.    One caution is the process events will have to know when its initialized so it can start working off the queue.




