#!/usr/bin/env bash


SAVED="`pwd`"
cd "`dirname \"$PRG\"`/.." >&-
APP_HOME="`pwd -P`"
cd "$SAVED" >&-

function waitForPort {

    (exec 6<>/dev/tcp/127.0.0.1/$1) &>/dev/null
    while [ $? -ne 0 ]
    do
        echo -n "."
        sleep 1
        (exec 6<>/dev/tcp/127.0.0.1/$1) &>/dev/null
    done
}

DEFAULT_LOCATOR_MEMORY="--initial-heap=128m --max-heap=128m"

DEFAULT_SERVER_MEMORY="--initial-heap=2g --max-heap=2g"

DEFAULT_JVM_OPTS=" --J=-XX:+UseParNewGC"
DEFAULT_JVM_OPTS="$DEFAULT_JVM_OPTS --J=-XX:+UseConcMarkSweepGC"
DEFAULT_JVM_OPTS="$DEFAULT_JVM_OPTS --J=-XX:CMSInitiatingOccupancyFraction=50"
DEFAULT_JVM_OPTS="$DEFAULT_JVM_OPTS --J=-XX:+CMSParallelRemarkEnabled"
DEFAULT_JVM_OPTS="$DEFAULT_JVM_OPTS --J=-XX:+UseCMSInitiatingOccupancyOnly"
DEFAULT_JVM_OPTS="$DEFAULT_JVM_OPTS --J=-XX:+ScavengeBeforeFullGC"
DEFAULT_JVM_OPTS="$DEFAULT_JVM_OPTS --J=-XX:+CMSScavengeBeforeRemark"
DEFAULT_JVM_OPTS="$DEFAULT_JVM_OPTS --J=-XX:+UseCompressedOops"
DEFAULT_JVM_OPTS="$DEFAULT_JVM_OPTS --mcast-port=0"

LOCATOR_OPTS="${DEFAULT_LOCATOR_MEMORY} ${DEFAULT_JVM_OPTS}"
LOCATOR_OPTS="${LOCATOR_OPTS} --name=locator_`hostname`"
LOCATOR_OPTS="${LOCATOR_OPTS} --port=10334"
LOCATOR_OPTS="${LOCATOR_OPTS} --dir=${APP_HOME}/data/locator"
LOCATOR_OPTS="${LOCATOR_OPTS} --J=-Dgemfire.security-manager=org.apache.geode.examples.security.ExampleSecurityManager"
LOCATOR_OPTS="${LOCATOR_OPTS} --security-properties-file=${APP_HOME}/config/gfsecurity.properties"
LOCATOR_OPTS="${LOCATOR_OPTS} --classpath=."

SERVER_OPTS="${DEFAULT_SERVER_MEMORY} ${DEFAULT_JVM_OPTS}"
SERVER_OPTS="${SERVER_OPTS} --locators=localhost[10334]"
SERVER_OPTS="${SERVER_OPTS} --server-port=0"
SERVER_OPTS="${SERVER_OPTS} --security-properties-file=${APP_HOME}/config/gfsecurity.properties"
SERVER_OPTS="${SERVER_OPTS} --classpath=."


mkdir -p ${APP_HOME}/data/locator
mkdir -p ${APP_HOME}/data/server1
mkdir -p ${APP_HOME}/data/server2

[ ! -f "${APP_HOME}/data/locator/locator10334view.dat" ]
firsttime=$?

find  ${APP_HOME}/data -type d -exec cp ${APP_HOME}/config/security.json {} \;

gfsh --e "start locator ${LOCATOR_OPTS}"  --e "configure pdx --read-serialized=true  --disk-store=DEFAULT" &

waitForPort 10334

if (( firsttime == 0 )); then
   echo waiting
   wait
fi

gfsh --e "start server  ${SERVER_OPTS} --name=server1 --dir=${APP_HOME}/data/server1" &
gfsh --e "start server  ${SERVER_OPTS} --name=server2 --dir=${APP_HOME}/data/server2" &


wait


gfsh << ENDGFSH
connect
member
1234567
   create region --name=test --type=PARTITION  --entry-time-to-live-expiration=60 --entry-time-to-live-expiration-action=destroy --enable-statistics=true
ENDGFSH

