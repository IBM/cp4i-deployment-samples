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

        //TO DO: EDIT/REMOVE - after get checks
//        SystemOfRecordMonitor.main(args);
    }
}
