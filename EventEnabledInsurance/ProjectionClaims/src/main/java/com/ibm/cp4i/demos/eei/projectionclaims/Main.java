package com.ibm.cp4i.demos.eei.projectionclaims;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;



import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadPoolExecutor;

public class Main {

    // port to listen connection
    static final int PORT = 8080;
    static final String HOSTNAME = "localhost";

    public static void main(String[] args) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(HOSTNAME, PORT), 0);
        // URL to search for a quote id: http://localhost:8080/quoteid=1
        // if 'quoteid' is changed, it will break (TO-DO: handle the break)
        server.createContext("/", new  MyHttpHandler());
        server.start();
        System.out.println(" Server started on port " + PORT);
    }
}
