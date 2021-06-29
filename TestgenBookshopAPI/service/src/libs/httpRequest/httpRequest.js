const axios = require('axios')

const RequestError = require('requesterror');

const prepareRequest = ({auth, request, serviceName, actualUrl = undefined}) => {
    const port = process.env.BOOK_LANG_PORT || 3000;
    const resource = actualUrl || request.originalUrl;

    var url
    if(process.env.RUN_LOCAL) {
        url = `http://localhost:${port}${resource}`;
    } else {
        url = `http://${serviceName}:5000${resource}`;
    }

    const requestHeaders = {
        "Content-Type": "application/json",
        "Authorization": auth
    };

    return ({
        url: url,
        reqHeaders: requestHeaders,
    });
}

const sendGetRequest = async (url, requestHeaders) => {
    try {
        return await axios.get(url, {
            headers: requestHeaders
        });
    } catch(error) {
        return generateErrorCase(error, 'GET', url);
    }
}

const sendPostRequest = async (url, requestHeaders, requestData) => {
    try {
        return await axios.post(url, requestData, {
            headers: requestHeaders
        });
    } catch(error) {
        return generateErrorCase(error, 'POST', url);
    }
}

const sendPutRequest = async (url, requestHeaders, requestData) => {
    try {
        return await axios.put(url, requestData, {
            headers: requestHeaders
        });
    } catch(error) {
        return generateErrorCase(error, 'PUT', url);
    }
}

const sendDeleteRequest =  async(url, requestHeaders) => {
    try {
        return await axios.delete(url, {
            headers: requestHeaders
        });
    } catch(error) {
        return generateErrorCase(error, 'DELETE', url);
    }
}

const generateErrorCase = (err, method, url) => {
    console.log(`ERROR: ${method} ${url}: ${err.message}`)
    var status = 500
    var code = 'internal_error'
    var message = 'The server was unable to process the request'
    var target
    const res = err.response
    if (res) {
        status = res.status
        var logMessage = `ERROR: Server responded with: ${status}`
        const data = res.data
        if (data?.target) {
            // local error model
            code = data.target.name
            message = data.message
            target = data.target.type
            logMessage = `${logMessage}: ${code}: ${message}`
        }
        else if (Array.isArray(data?.errors) && data.errors.length > 0) {
            // error model specified by the API doc
            code = data.errors[0].code
            message = data.errors[0].message
            logMessage = `${logMessage}: ${code}: ${message}`
        }
        console.log(logMessage)
    }
    return new RequestError(status, code, message, target)
}

module.exports = {
    prepareRequest,
    sendGetRequest,
    sendPostRequest,
    sendPutRequest,
    sendDeleteRequest
};
