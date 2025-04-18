#!/bin/bash
#
# Copyright (c) 2020-2023, NVIDIA CORPORATION. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -ex
rm -rf deploy
mkdir -p deploy
cd deploy
tar -zxf ../spark-rapids-built.tgz
cd spark-rapids
echo "Maven mirror is $MVN_URM_MIRROR"
SERVER_ID='snapshots'
SERVER_URL="$URM_URL-local"
SCALA_VERSION=`mvn help:evaluate -q -pl dist -Dexpression=scala.binary.version -DforceStdout`
# remove the periods so change something like 3.2.1 to 321
VERSION_NUM=${BASE_SPARK_VERSION_TO_INSTALL_DATABRICKS_JARS//.}
SPARK_VERSION_STR=spark$VERSION_NUM
SPARK_PLUGIN_JAR_VERSION=`mvn help:evaluate -q -pl dist -Dexpression=project.version -DforceStdout`
# Append 143 into the db shim version because Databricks 14.3.x and 15.4.x are both based on spark version 3.5.0
if [[ "$DB_RUNTIME" == "14.3"* ]]; then
    DB_SHIM_NAME="${SPARK_VERSION_STR}db143"
else
    DB_SHIM_NAME="${SPARK_VERSION_STR}db"
fi
DBJARFPATH=./aggregator/target/${DB_SHIM_NAME}/rapids-4-spark-aggregator_$SCALA_VERSION-$SPARK_PLUGIN_JAR_VERSION-${DB_SHIM_NAME}.jar
echo "Databricks jar is: $DBJARFPATH"
MVN="mvn -Dmaven.wagon.http.retryHandler.count=3 -DretryFailedDeploymentCount=3"
$MVN -B deploy:deploy-file $MVN_URM_MIRROR -Durl=$SERVER_URL -DrepositoryId=$SERVER_ID \
    -Dfile=$DBJARFPATH -DpomFile=aggregator/pom.xml -Dclassifier=$DB_SHIM_NAME
# Deploy the sql-plugin-api jar
DB_PLUGIN_API_JAR_PATH=./sql-plugin-api/target/${DB_SHIM_NAME}/rapids-4-spark-sql-plugin-api_$SCALA_VERSION-$SPARK_PLUGIN_JAR_VERSION-${DB_SHIM_NAME}.jar
$MVN -B deploy:deploy-file $MVN_URM_MIRROR -Durl=$SERVER_URL -DrepositoryId=$SERVER_ID \
    -Dfile=$DB_PLUGIN_API_JAR_PATH -DpomFile=./sql-plugin-api/pom.xml -Dclassifier=$DB_SHIM_NAME
# Deploy the integration test jar
DBINTTESTJARFPATH=./integration_tests/target/rapids-4-spark-integration-tests_$SCALA_VERSION-$SPARK_PLUGIN_JAR_VERSION-${DB_SHIM_NAME}.jar
$MVN -B deploy:deploy-file $MVN_URM_MIRROR -Durl=$SERVER_URL -DrepositoryId=$SERVER_ID \
    -Dfile=$DBINTTESTJARFPATH -DpomFile=integration_tests/pom.xml -Dclassifier=$DB_SHIM_NAME
