package com.ibm.cp4i.demos.eei.projectionclaims;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;

public class Main {

    // port to listen connection
    static final int PORT = 8080;
    static final String HOSTNAME = "localhost";

    public static void main(String[] args) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(HOSTNAME, PORT), 0);
        SystemOfRecordMonitor monitor = new SystemOfRecordMonitor("es-demo-kafka-bootstrap.cp4i1.svc:9092");
//        SystemOfRecordMonitor monitor = new SystemOfRecordMonitor("es-demo-kafka-bootstrap-dans.dan-pc-e2e-ec111ed5d7db435e1c5eeeb4400d693f-0000.eu-gb.containers.appdomain.cloud:443");
//        monitor.addScramProperties("es-demo-scram", "byX0BQ4gFMpm");
//        monitor.addTLSProperties("/Users/kinshuk.bhardwajibm.com/Downloads/dan-pc-e2e.p12", "M62dqL41pZBd");
        try {
            monitor.start();
        } catch (Throwable exception) {
            exception.printStackTrace();
            throw exception;
        }
        /*
        this context route is to search for a particular quote id
        http://localhost:8080/quoteid=1
        */
        server.createContext("/", new  MyHttpHandler(monitor));
        //this context route is to search for all table data
        server.createContext("/getalldata", new  MyHttpHandler(monitor));
        server.start();
        System.out.println(" Server started on port " + PORT);
    }
}
