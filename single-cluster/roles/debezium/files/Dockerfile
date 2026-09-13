FROM quay.io/debezium/connect:3.4.0.Final

USER root

ENV PLUGIN_DIR=/kafka/connect/plugins
ENV KAFKA_CONNECT_JDBC_SOURCE_DIR=$PLUGIN_DIR/kafka-connect-jdbc-source

# Create the plugin directory if it doesn't exist
RUN mkdir -p $PLUGIN_DIR

# Download necessary JARs and place them in the plugin directory
# ref: https://debezium.io/documentation/reference/stable/configuration/avro.html
RUN curl -L -o $PLUGIN_DIR/kafka-connect-avro-converter.jar \
    https://packages.confluent.io/maven/io/confluent/kafka-connect-avro-converter/7.3.0/kafka-connect-avro-converter-7.3.0.jar && \
    curl -L -o $PLUGIN_DIR/kafka-connect-avro-data.jar \
    https://packages.confluent.io/maven/io/confluent/kafka-connect-avro-data/7.3.0/kafka-connect-avro-data-7.3.0.jar && \
    curl -L -o $PLUGIN_DIR/kafka-avro-serializer.jar \
    https://packages.confluent.io/maven/io/confluent/kafka-avro-serializer/7.3.0/kafka-avro-serializer-7.3.0.jar && \
    curl -L -o $PLUGIN_DIR/kafka-schema-serializer.jar \
    https://packages.confluent.io/maven/io/confluent/kafka-schema-serializer/7.3.0/kafka-schema-serializer-7.3.0.jar && \
    curl -L -o $PLUGIN_DIR/kafka-schema-converter.jar \
    https://packages.confluent.io/maven/io/confluent/kafka-schema-converter/7.3.0/kafka-schema-converter-7.3.0.jar && \
    curl -L -o $PLUGIN_DIR/kafka-schema-registry-client.jar \
    https://packages.confluent.io/maven/io/confluent/kafka-schema-registry-client/7.3.0/kafka-schema-registry-client-7.3.0.jar && \
    curl -L -o $PLUGIN_DIR/common-config.jar \
    https://packages.confluent.io/maven/io/confluent/common-config/7.3.0/common-config-7.3.0.jar && \
    curl -L -o $PLUGIN_DIR/common-utils.jar \
    https://packages.confluent.io/maven/io/confluent/common-utils/7.3.0/common-utils-7.3.0.jar && \
    curl -L -o $PLUGIN_DIR/avro.jar \
    https://repo1.maven.org/maven2/org/apache/avro/avro/1.10.2/avro-1.10.2.jar && \
    curl -L -o $PLUGIN_DIR/commons-compress.jar \
    https://repo1.maven.org/maven2/org/apache/commons/commons-compress/1.21/commons-compress-1.21.jar && \
    curl -L -o $PLUGIN_DIR/failureaccess.jar \
    https://repo1.maven.org/maven2/com/google/guava/failureaccess/1.0.1/failureaccess-1.0.1.jar && \
    curl -L -o $PLUGIN_DIR/guava.jar \
    https://repo1.maven.org/maven2/com/google/guava/guava/31.1-jre/guava-31.1-jre.jar && \
    curl -L -o $PLUGIN_DIR/minimal-json.jar \
    https://repo1.maven.org/maven2/com/eclipsesource/minimal-json/minimal-json/0.9.5/minimal-json-0.9.5.jar && \
    curl -L -o $PLUGIN_DIR/re2j.jar \
    https://repo1.maven.org/maven2/com/google/re2j/re2j/1.3/re2j-1.3.jar && \
    curl -L -o $PLUGIN_DIR/slf4j-api.jar \
    https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.32/slf4j-api-1.7.32.jar && \
    curl -L -o $PLUGIN_DIR/snakeyaml.jar \
    https://repo1.maven.org/maven2/org/yaml/snakeyaml/1.30/snakeyaml-1.30.jar && \
    curl -L -o $PLUGIN_DIR/swagger-annotations.jar \
    https://repo1.maven.org/maven2/io/swagger/swagger-annotations/1.6.4/swagger-annotations-1.6.4.jar && \
    curl -L -o $PLUGIN_DIR/jackson-databind.jar \
    https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.13.3/jackson-databind-2.13.3.jar && \
    curl -L -o $PLUGIN_DIR/jackson-core.jar \
    https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/2.13.3/jackson-core-2.13.3.jar && \
    curl -L -o $PLUGIN_DIR/jackson-annotations.jar \
    https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-annotations/2.13.3/jackson-annotations-2.13.3.jar && \
    curl -L -o $PLUGIN_DIR/jackson-dataformat-csv.jar \
    https://repo1.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-csv/2.13.3/jackson-dataformat-csv-2.13.3.jar && \
    curl -L -o $PLUGIN_DIR/logredactor.jar \
    https://repo1.maven.org/maven2/io/confluent/logredactor/7.3.0/logredactor-7.3.0.jar && \
    curl -L -o $PLUGIN_DIR/logredactor-metrics.jar \
    https://repo1.maven.org/maven2/io/confluent/logredactor-metrics/7.3.0/logredactor-metrics-7.3.0.jar

RUN mkdir -p $KAFKA_CONNECT_JDBC_SOURCE_DIR

# Download Oracle Instant Client 19c (exact match with database)
RUN curl -o instantclient-basic.zip \
    https://download.oracle.com/otn_software/linux/instantclient/1928000/instantclient-basic-linux.x64-19.28.0.0.0dbru.zip && \
    curl -o instantclient-jdbc.zip \
    https://download.oracle.com/otn_software/linux/instantclient/1928000/instantclient-jdbc-linux.x64-19.28.0.0.0dbru.zip && \
    curl -o instantclient-sqlplus.zip \
    https://download.oracle.com/otn_software/linux/instantclient/1928000/instantclient-sqlplus-linux.x64-19.28.0.0.0dbru.zip

# Extract all instant client packages
RUN unzip instantclient-basic.zip -d /opt/oracle && \
    unzip -o instantclient-jdbc.zip -d /opt/oracle && \
    unzip -o instantclient-sqlplus.zip -d /opt/oracle && \
    rm -f *.zip

# Create libs directory and copy JARs
RUN mkdir -p /kafka/libs && \
    cp /opt/oracle/instantclient_19_28/*.jar /kafka/libs/ || true && \
    ls -la /kafka/libs/

# Set environment variables
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient_19_28:$LD_LIBRARY_PATH
ENV ORACLE_HOME=/opt/oracle/instantclient_19_28

# Set permissions
RUN chown -R kafka:kafka /kafka/libs /opt/oracle

USER kafka
