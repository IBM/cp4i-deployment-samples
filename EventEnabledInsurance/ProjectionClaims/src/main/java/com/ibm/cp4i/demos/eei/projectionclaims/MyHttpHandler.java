package com.ibm.cp4i.demos.eei.projectionclaims;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.OutputStream;

public class MyHttpHandler implements HttpHandler {
    @Override
    public void handle(HttpExchange httpExchange) throws IOException {
        String requestParamValue = null;
        if ("GET".equals(httpExchange.getRequestMethod())) {
            requestParamValue = handleGetRequest(httpExchange);
        }
        // TO-DO: handle all other types of requests?
        handleResponse(httpExchange, requestParamValue);
    }

    private String handleGetRequest(HttpExchange httpExchange) {
        return httpExchange.
                getRequestURI()
                .toString()
                .split("quoteid")[1]
                .split("=")[1];
    }

    private void handleResponse(HttpExchange httpExchange, String requestParamValue) throws IOException {
        OutputStream outputStream = httpExchange.getResponseBody();
        StringBuilder contentBuilder = new StringBuilder();
        BufferedReader in = new BufferedReader(new FileReader("./src/main/resources/index.html"));
        String str;
        while ((str = in.readLine()) != null) {
            if (str.equalsIgnoreCase("<h2>We're starting here!</h2>")) {
                contentBuilder.append("<h2>Searching the quote id: " + requestParamValue + "</h2>");
            } else {
                contentBuilder.append(str);
            }
        }
        in.close();
        String htmlResponse = contentBuilder.toString();
//        String htmlResponse = "<html>" +
//                "<body>" +
//                "<h1>" +
//                "Hello " +
//                requestParamValue +
//                "</h1>" +
//                "</body>" +
//                "</html>"
//                ;

        // debug log for server
        System.out.println("id searched is: " + requestParamValue);

        // this line is a must
        httpExchange.sendResponseHeaders(200, htmlResponse.length());
        outputStream.write(htmlResponse.getBytes());
        outputStream.flush();
        outputStream.close();
    }
}
