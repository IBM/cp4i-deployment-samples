'use strict';

const { diag, DiagConsoleLogger, DiagLogLevel } = require("@opentelemetry/api");
const { NodeTracerProvider } = require("@opentelemetry/node");
const { BatchSpanProcessor } = require("@opentelemetry/tracing");
const { JaegerExporter } = require('@opentelemetry/exporter-jaeger')
const { JaegerPropagator } = require('@opentelemetry/propagator-jaeger')
const { registerInstrumentations } = require("@opentelemetry/instrumentation");
const { HttpInstrumentation } = require("@opentelemetry/instrumentation-http");
const { GrpcInstrumentation } = require("@opentelemetry/instrumentation-grpc");

diag.setLogger(new DiagConsoleLogger(), DiagLogLevel.ALL);

const provider = new NodeTracerProvider();

const serviceName = process.env.JAEGER_SERVICE_NAME || 'bookshop-books'

class MySpanProcessor extends BatchSpanProcessor {
    constructor(exporter) {
        super(exporter)
    }
    onStart(span) {
        super.onStart(span)
        span.setAttribute('service.name', serviceName)
    }
}

provider.addSpanProcessor(
    new MySpanProcessor(
        new JaegerExporter({
            serviceName: serviceName,
            logger: provider.logger,
        })
    )
);

provider.register({
    propagator: new JaegerPropagator()
});

registerInstrumentations({
    instrumentations: [
        new HttpInstrumentation(),
        new GrpcInstrumentation(),
    ],
});

console.log("tracing initialized");
