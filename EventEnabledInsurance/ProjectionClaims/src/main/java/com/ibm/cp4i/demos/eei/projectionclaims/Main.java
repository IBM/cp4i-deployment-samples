package com.ibm.cp4i.demos.eei.projectionclaims;

import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.net.InetSocketAddress;

public class Main {
    static final int PORT = 9000;
    public static void main(String[] args) throws IOException {
        System.out.println("Hello world");
        // Construct an HTTP server object
        HttpServer server = HttpServer.create(new InetSocketAddress("localhost", Main.PORT), 0);
        System.out.println("server started at " + Main.PORT);
        // Implement HTTP handler to process GET/POST requests and generate responses
        server.createContext("/", new RootHandler());
        // HTTP handler objects to the HTTP server object
        server.createContext("/echoHeader", new EchoHeaderHandler());
        server.createContext("/echoGet", new EchoGetHandler());
        server.setExecutor(null);
        server.start();
    }
}
