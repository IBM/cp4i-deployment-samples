package com.ibm.cp4i.demos.eei.projectionclaims;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.kafka.clients.CommonClientConfigs;
import org.apache.kafka.common.config.SaslConfigs;
import org.apache.kafka.common.config.SslConfigs;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.common.utils.Bytes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.state.KeyValueIterator;
import org.apache.kafka.streams.state.KeyValueStore;
import org.apache.kafka.streams.state.QueryableStoreTypes;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;

import java.nio.charset.StandardCharsets;
import java.util.Properties;

@SuppressWarnings({"unused", "RedundantSuppression"})
public class SystemOfRecordMonitor {
    private final static String SOURCE_TOPIC = "sor.public.quotes";
    private final static String STORE = "sor.store";
    private final Properties properties = new Properties();
    private ReadOnlyKeyValueStore<Bytes, Bytes> view = null;

    public SystemOfRecordMonitor(String bootstrapServers) {
        properties.put(StreamsConfig.APPLICATION_ID_CONFIG, SOURCE_TOPIC + "-cdc");
        properties.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.Bytes().getClass());
        properties.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.Bytes().getClass());
        properties.put(CommonClientConfigs.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
    }

    /**
     * If connecting to a secured bootstrap server then need to get this username/password from the EventStreams UI. Go
     * to "Home" -> "Connect to this cluster" -> "Generate SCRAM credentials". Need to:
     * - Specify the Credential Name.
     * - Choose "Consume messages only, and read schemas"
     * - Choose "All topics"
     * - Choose "All consumer groups"
     * - Choose "No transactional IDs"
     * @param scramUsername The "Credential Name" specified above.
     * @param scramPassword Get from the generated secret using:
     *   $ SCRAM_USERNAME=<Credential Name>
     *   $ SCRAM_PASSWORD=$(oc get secret $SCRAM_USERNAME -o json | jq -r '.data.password' | base64 --decode)
     *   $ echo "SCRAM_PASSWORD=$SCRAM_PASSWORD"
     */
    public void addScramProperties(String scramUsername, String scramPassword) {
        properties.put(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, "SASL_SSL");
        properties.put(SaslConfigs.SASL_MECHANISM, "SCRAM-SHA-512");
        String saslJaasConfig = "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"" + scramUsername + "\" password=\"" + scramPassword + "\";";
        properties.put(SaslConfigs.SASL_JAAS_CONFIG, saslJaasConfig);
    }

    /**
     * If connecting to an external bootstrap server (not an internal service name) then this is needed. Go
     * to "Home" -> "Connect to this cluster", then click Download Certificate" in the "PKCS12 certificate" box.
     * @param truststorePath The path to the downloaded certificate
     * @param password The password presented in the UI
     */
    public void addTLSProperties(String truststorePath, String password) {
        properties.put(SslConfigs.SSL_PROTOCOL_CONFIG, "TLSv1.2");
        properties.put(SslConfigs.SSL_TRUSTSTORE_LOCATION_CONFIG, truststorePath);
        properties.put(SslConfigs.SSL_TRUSTSTORE_PASSWORD_CONFIG, password);
    }

    @SuppressWarnings("deprecation")
    public void start() {
        StreamsBuilder builder = new StreamsBuilder();
        builder.globalTable(SOURCE_TOPIC, Materialized.<Bytes, Bytes, KeyValueStore<Bytes, byte[]>>as(STORE));
        KafkaStreams streams = new KafkaStreams(builder.build(), properties);
        streams.start();
        view = streams.store(STORE, QueryableStoreTypes.keyValueStore());
    }

    public JsonNode getRow(String quoteID) {
        final JsonNode[] result = {null};
        KeyValueIterator<Bytes, Bytes> all = view.all();
        ObjectMapper mapper = new ObjectMapper();
        all.forEachRemaining(keyValue -> {
            if(result[0] == null) {
                try {
                    JsonNode json = mapper.readTree(new String(keyValue.value.get(), StandardCharsets.UTF_8));
                    JsonNode after = json.get("payload").get("after");
                    if(after.get("quoteid").asText().equals(quoteID)) {
                        result[0] = after;
                    }
                } catch (JsonProcessingException exception) {
                    exception.printStackTrace();
                }
            }
        });
        return result[0];
    }

    public JsonNode getTable() throws JsonProcessingException {
        StringBuffer result = new StringBuffer();
        result.append("[");

        KeyValueIterator<Bytes, Bytes> all = view.all();
        ObjectMapper mapper = new ObjectMapper();
        final boolean[] needComma = {false};
        all.forEachRemaining(keyValue -> {
            try {
                JsonNode json = mapper.readTree(new String(keyValue.value.get(), StandardCharsets.UTF_8));
                JsonNode after = json.get("payload").get("after");
                if(needComma[0]) {
                    result.append(",");
                }
                needComma[0] = true;
                result.append(after.toString());
            } catch (JsonProcessingException exception) {
                exception.printStackTrace();
            }
        });
        result.append("]");
        return mapper.readTree(result.toString());
    }

    @SuppressWarnings({"InfiniteLoopStatement", "BusyWait"})
    public static void main(String[] args) {
        SystemOfRecordMonitor monitor;
        try {
            // the end point could be the kafka external listener too
            monitor = new SystemOfRecordMonitor("es-demo-kafka-bootstrap:9092");
            // monitor.addScramProperties("es-demo-scram", "<pass1>>");
            // monitor.addTLSProperties("<path-to>/es-cert-cluster.p12", "<pass2>");
            monitor.start();
        } catch (Throwable exception) {
            exception.printStackTrace();
            throw exception;
        }
        String id = null;
        while (true) {
            try {
                Thread.sleep(5000);
                JsonNode table = monitor.getTable();
                System.out.println("===");
                System.out.println(table.toPrettyString());
                if(id == null) {
                    JsonNode firstRow = table.get(0);
                    if(firstRow != null) {
                        id = firstRow.get("quoteid").asText();
                    }
                }
                if(id != null) {
                    System.out.println("---");
                    JsonNode row = monitor.getRow(id);
                    if(row==null) {
                        System.out.println("<null>");
                    } else {
                        System.out.println(row.toPrettyString());
                    }
                }
            } catch (Throwable exception) {
                exception.printStackTrace();
            }
        }
    }
}
