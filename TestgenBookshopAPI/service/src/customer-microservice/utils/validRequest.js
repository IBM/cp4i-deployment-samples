const RequestError = require('requesterror');

const checkValidRequest = contentTypeHeader => {
    if (contentTypeHeader !== 'application/json') {
        return new RequestError(415, 'missing_header', 'Content-Type is missing or is not supported', 'header');
    }
    return true;
}

module.exports = checkValidRequest;