package com.ibm.cp4i.demos.eei.projectionclaims;

import com.fasterxml.jackson.databind.JsonNode;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.io.OutputStream;

public class MyHttpHandler implements HttpHandler {
    SystemOfRecordMonitor monitor;
    public MyHttpHandler(SystemOfRecordMonitor monitor) {
        this.monitor = monitor;
    }

    @Override
    public void handle(HttpExchange httpExchange) throws IOException {
        String requestParamValue = null;
        if ("GET".equals(httpExchange.getRequestMethod())) {
            requestParamValue = handleGetRequest(httpExchange);
        }
        requestParamValue = (requestParamValue == null) ? "" : requestParamValue;
        handleResponse(httpExchange, requestParamValue);
    }

    private String handleGetRequest(HttpExchange httpExchange) {
        System.out.println(httpExchange.getRequestURI().toString());
        String quoteId;
        if (httpExchange.getRequestURI().toString().equalsIgnoreCase("/getalldata")) {
            quoteId = "all";
        }
        else if (httpExchange.getRequestURI().toString().contains("/quoteid=")) {
            quoteId = httpExchange.
                    getRequestURI()
                    .toString()
                    .split("quoteid")[1]
                    .split("=")[1];
        } else {
            quoteId="";
        }
        return quoteId;
    }

    private void handleResponse(HttpExchange httpExchange, String requestParamValue) throws IOException {
        OutputStream outputStream = httpExchange.getResponseBody();
        StringBuilder contentBuilder = new StringBuilder();
        String htmlResponse, str;
        BufferedReader in;
        // get all table data
        if (requestParamValue.equalsIgnoreCase("all")) {
            System.out.println("Requested for all data");
            in = new BufferedReader(new FileReader("./src/main/resources/index.html"));
            try {
                JsonNode table = this.monitor.getTable();
                System.out.println("==============================");
                while ((str = in.readLine()) != null) {
                    if (str.equalsIgnoreCase("<h2>We're starting here!</h2>") && (table == null)) {
                        contentBuilder.append("<h2>Searched for the quote id: ").append(requestParamValue).append(", but no record found.").append("</h2>");
                    } else if (str.equalsIgnoreCase("<h2>We're starting here!</h2>") && (table != null)) {
                        System.out.println("Total data found: " + table.size());
                        contentBuilder.append("<h2>Searched for all table data and found ").append(table.size()).append(" records:").append("</h2>");
                        contentBuilder.append("<h3>").append(table.toPrettyString()).append("</h3>");
                    } else {
                        contentBuilder.append(str);
                    }
                }
            } catch (Throwable exception) {
                exception.printStackTrace();
            }
        }
        // get a particular quote id
        else if (!requestParamValue.isEmpty()) {
            System.out.println("Requested for a particular quote id " + requestParamValue);
            in = new BufferedReader(new FileReader("./src/main/resources/index.html"));
            try {
                System.out.println("==============================");
                int id = Integer.parseInt(requestParamValue);
                JsonNode row = this.monitor.getRow(id);
                while ((str = in.readLine()) != null) {
                    if (str.equalsIgnoreCase("<h2>We're starting here!</h2>") && (row == null)) {
                        contentBuilder.append("<h2>Searched for the quote id: ").append(requestParamValue).append(", but no record found.").append("</h2>");
                    } else if (str.equalsIgnoreCase("<h2>We're starting here!</h2>") && (row != null)) {
                        System.out.println(row.toPrettyString());
//                        contentBuilder.append("<h2>Searched for the quote id: ").append(requestParamValue).append(", found the following data.").append("</h2>");
                        contentBuilder.append(
                                "<table style=\"width:100%\">" +
                                "<caption><h4>Claim status for " + row.get("name").toString().replace("\"", "") + ":</h4></caption>" +
                                "<tr>" +
                                    "<th>QuoteID</th>" +
                                    "<th>Name</th>" +
                                    "<th>Email</th>" +
                                    "<th>Address</th>" +
                                    "<th>US State</th>" +
                                    "<th>License Plate</th>" +
                                    "<th>Claim Status</th>" +
                                "</tr>" +
                                "<tr>" +
                                    "<td>"+row.get("quoteid").toString().replace("\"", "")+"</th>" +
                                    "<td>"+row.get("name").toString().replace("\"", "")+"</th>" +
                                    "<td>"+row.get("email").toString().replace("\"", "")+"</th>" +
                                    "<td>"+row.get("address").toString().replace("\"", "")+"</th>" +
                                    "<td>"+row.get("usstate").toString().replace("\"", "")+"</th>" +
                                    "<td>"+row.get("licenseplate").toString().replace("\"", "")+"</th>" +
                                    "<td>"+row.get("claimstatus").toString().replace("\"", "")+"</th>" +
                                "</tr>");
                    } else {
                        contentBuilder.append(str);
                    }
                }
            } catch (Throwable exception) {
                exception.printStackTrace();
            }
        } else {
            System.out.println("Unsupported request");
            in = new BufferedReader(new FileReader("./src/main/resources/404.html"));
            while ((str = in.readLine()) != null) {
                if (str.equalsIgnoreCase("<h2>We're starting here!</h2>")) {
                    contentBuilder.append("<h2>Searching the quote id: ").append(requestParamValue).append("</h2>");
                } else {
                    contentBuilder.append(str);
                }
            }
        }
        in.close();
        htmlResponse = contentBuilder.toString();
        httpExchange.sendResponseHeaders(200, htmlResponse.length());
        outputStream.write(htmlResponse.getBytes());
        outputStream.flush();
        outputStream.close();
    }
}
