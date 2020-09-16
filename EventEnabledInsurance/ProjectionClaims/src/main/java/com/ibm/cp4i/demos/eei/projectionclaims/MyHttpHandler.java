package com.ibm.cp4i.demos.eei.projectionclaims;

import com.fasterxml.jackson.databind.JsonNode;
import com.sun.net.httpserver.HttpExchange;
import org.json.JSONObject;
import com.sun.net.httpserver.HttpHandler;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

public class MyHttpHandler implements HttpHandler {
    SystemOfRecordMonitor monitor;

    public MyHttpHandler(SystemOfRecordMonitor monitor) {
        this.monitor = monitor;
    }

    @Override
    public void handle(HttpExchange httpExchange) {
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
            System.out.println("Set the request param to 'all'");
        } else if (httpExchange.getRequestURI().toString().contains("/quoteid=")) {
            quoteId = httpExchange.
                    getRequestURI()
                    .toString()
                    .split("quoteid")[1]
                    .split("=")[1];
            System.out.println("Set the request param to " + quoteId);
        } else {
            quoteId = "";
            System.out.println("Set the request param to empty");
        }
        return quoteId;
    }

    @SuppressWarnings("StringConcatenationInsideStringBufferAppend")
    public static void createTableForAllData(JsonNode table, StringBuilder contentBuilder) {
        for (int counter = 0; counter < table.size(); counter++) {
            JsonNode row = table.get(counter);
            String quoteid = row.get("quoteid").toString().replace("\"", "");
            contentBuilder.append
            (
                "<tr>" +
                    "<td><a href=\"quoteid=" + quoteid + "\">" + quoteid + "</a></th>" +
                    "<td>" + row.get("name").toString().replace("\"", "") + "</th>" +
                    "<td>" + row.get("email").toString().replace("\"", "") + "</th>" +
                    "<td>" + row.get("address").toString().replace("\"", "") + "</th>" +
                    "<td>" + row.get("usstate").toString().replace("\"", "") + "</th>" +
                    "<td>" + row.get("licenseplate").toString().replace("\"", "") + "</th>" +
                    "<td>" + row.get("claimstatus").toString().replace("\"", "") + "</th>" +
                "</tr>"
            );
        }
    }

    private void handleResponse(HttpExchange httpExchange, String requestParamValue) {
        try {
            OutputStream outputStream = httpExchange.getResponseBody();
            StringBuilder contentBuilder = new StringBuilder();
            String htmlResponse;
            // get all table data
            if (requestParamValue.equalsIgnoreCase("all")) {
                System.out.println("Requested for all data");
                try {
                    JsonNode table = this.monitor.getTable();
                    contentBuilder.append
                    (
                        "<!DOCTYPE html>" +
                        "<html lang=en>" +
                        "<head>" +
                            "<link rel=icon href=data:,>" +
                            "<meta charset=UTF-8>" +
                            "<style>" +
                                "table, th, td {" +
                                    "border: 1px solid black;" +
                                "}" +
                                "th, td {" +
                                    "padding: 5px;" +
                                "}" +
                            "</style>" +
                            "<title>Projection Claim Application</title>" +
                        "</head>" +
                        "<body>"
                    );
                    if (table == null) {
                        System.out.println("No records found");
                        contentBuilder.append("<h2>No records found").append("</h2>");
                    } else {
                        System.out.println("Total records found: " + table.size());
                        contentBuilder.append("<h4>Searched for all table data and found ").append(table.size()).append(" records:").append("</h4>");
                        contentBuilder.append
                        (
                            "<table style=\"width:100%\">" +
                                "<caption><h4>All claims</h4></caption>" +
                                "<tr>" +
                                "<th>QuoteID</th>" +
                                "<th>Name</th>" +
                                "<th>Email</th>" +
                                "<th>Address</th>" +
                                "<th>US State</th>" +
                                "<th>License Plate</th>" +
                                "<th>Claim Status</th>" +
                            "</tr>"
                        );
                        createTableForAllData(table, contentBuilder);
                    }
                    contentBuilder.append
                    (
                        "</body>" +
                        "</html>"
                    );
                } catch (Throwable exception) {
                    exception.printStackTrace();
                }
                htmlResponse = contentBuilder.toString();
                httpExchange.sendResponseHeaders(200, htmlResponse.length());
                outputStream.write(htmlResponse.getBytes());
                System.out.println("------------------------------------------------");
            }
            // get a particular record
            else if (!requestParamValue.isEmpty()) {
                System.out.println("Requested for a particular quote id: " + requestParamValue);
                JSONObject trimmedRow = new JSONObject();
                byte[] byteResponse;
                try {
                    JsonNode row = this.monitor.getRow(requestParamValue);
                    if (row != null) {
                        trimmedRow.put("quoteid", row.get("quoteid").asText());
                        trimmedRow.put("name", row.get("name").asText());
                        trimmedRow.put("email", row.get("email").asText());
                        trimmedRow.put("address", row.get("address").asText());
                        trimmedRow.put("usstate", row.get("usstate").asText());
                        trimmedRow.put("licenseplate", row.get("licenseplate").asText());
                        trimmedRow.put("claimstatus", row.get("claimstatus").asText());
                        byteResponse = trimmedRow.toString(4).getBytes(StandardCharsets.UTF_8);
                        httpExchange.sendResponseHeaders(200, byteResponse.length);
                    } else {
                        System.out.println("No record found with id: " + requestParamValue);
                        byteResponse = trimmedRow.toString(4).getBytes(StandardCharsets.UTF_8);
                        httpExchange.sendResponseHeaders(404, byteResponse.length);
                    }
                    outputStream.write(byteResponse);
                } catch (Exception ex) {
                    ex.printStackTrace();
                }
                System.out.println(trimmedRow.toString(4));
                System.out.println("------------------------------------------------");
            } else {
                System.out.println("Unsupported request");
                contentBuilder.append
                (
                    "<!DOCTYPE html>" +
                    "<html lang=en>" +
                    "<head>" +
                        "<link rel=icon href=data:,>" +
                        "<meta charset=UTF-8>" +
                        "<title>Unsupported Request</title>" +
                    "</head>" +
                    "<body>" +
                    "<h2>404 Not Found</h2>" +
                    "</body>" +
                    "</html>"
                );
                htmlResponse = contentBuilder.toString();
                httpExchange.sendResponseHeaders(404, htmlResponse.length());
                outputStream.write(htmlResponse.getBytes());
                System.out.println("------------------------------------------------");
            }
            outputStream.flush();
            outputStream.close();
        } catch (Exception e) {
            System.out.println("Error occurred");
            e.printStackTrace();
        }
    }
}
