package com.ibm.cp4i.demos.eei.projectionclaims;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;

public class Main {

    // port to listen connection
    static final int PORT = 8080;
    static final String HOSTNAME = "localhost";

    public static void main(String[] args) throws IOException {
        SystemOfRecordMonitor monitor = new SystemOfRecordMonitor("es-demo-kafka-bootstrap.cp4i1.svc:9092");

//        monitor = new SystemOfRecordMonitor("minimal-prod-kafka-bootstrap-cp4i2.dan-debezium-e2e-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud:443");
//        monitor.addScramProperties("dan-test", "SCGg6kfxjJ1H");
//        monitor.addTLSProperties("/Users/daniel.pinkuk.ibm.com/Downloads/dan-test.p12", "VoA8LSmGY3rx");

        HttpServer server = HttpServer.create(new InetSocketAddress(HOSTNAME, PORT), 0);
        /*
        this context route is to search for a particular quote id
        http://localhost:8080/quoteid=1
        if 'quoteid' is changed, it will break (TO-DO: handle the break)
        */
        server.createContext("/", new  MyHttpHandler());
        //this context route is to search for all table data
        server.createContext("/getalldata", new  MyHttpHandler());
        server.start();
        System.out.println(" Server started on port " + PORT);

//        SystemOfRecordMonitor.main(args);
        System.out.println("----------------------------------");
        try {
            monitor.start();
        } catch (Throwable exception) {
            exception.printStackTrace();
            throw exception;
        }

        try {
            System.out.println("----------------------------------");
            String id_str = "10";
            Integer id = Integer.valueOf(id_str);
            if(id != null) {
                JsonNode row = monitor.getRow(id);
                System.out.println(row.toPrettyString());
            }
        } catch (NumberFormatException nfe) {
            nfe.printStackTrace();
        } catch (Throwable exception) {
            exception.printStackTrace();
        }
        System.out.println("========================================== TABLE DATA ENDS HERE ========================================================");
    }
}
