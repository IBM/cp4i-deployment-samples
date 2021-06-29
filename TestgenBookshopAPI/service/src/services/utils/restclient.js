const axios = require('axios')

const RequestError = require('requesterror');

async function post(url, auth, body, options = {}) {
    const headers = {
        'Content-Type': 'application/json',
        'Authorization': auth,
        ...options.axios?.headers
    }
    try {
        const response = await axios.post(url, body, {
            ...options.axios,
            headers: headers
        })
        return response
    }
    catch (err) {
        raiseError(err)
    }
}

function raiseError(err, url) {
    console.log(`POST ${url}: call failed: ${err.message}`)
    const res = err.response
    if (res) {
        const error = getErrorFromResponse(res)
        console.log(`Server responded with: ${res.status}: ${error.code}: ${error.message}`)
    }
    throw new RequestError(500, 'internal_error', 'The server was unable to process the request')
}

function getErrorFromResponse(res) {
    const errors = res?.data?.errors
    return Array.isArray(errors) && errors.length && errors[0] || {}
}

module.exports = {
    post
}
