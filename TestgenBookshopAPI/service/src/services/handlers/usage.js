const RequestError = require('requesterror')
const authenticate = require('../utils/authenticate')
const delay = require('../utils/delay')
const { checkStringField, checkAdditionalFields } = require('../utils/validate');

var usageCount = 1200

async function postUsage(req, res, next) {
    var usage
    try {
        authenticate(req, 'admin')
        checkBody(req)
        await delay(100)
        usage = getUsage(req.body.service)
    }
    catch (err) {
        return next(err)
    }
    res.status(200).json({
        service: req.body.service,
        usage: usage
    })
}

function checkBody(req) {
    checkStringField(req, 'service')
    checkAdditionalFields(req, ['service'])

    const service = req.body.service
    const services = ['author','category']
    if (!services.includes(service)) {
        throw new RequestError(400, 'invalid_input', `The name \'${service}\' is not recognised as a service`, target = {
            type: 'field',
            name: 'service'
        })
    }
}

function getUsage(service) {
    return ++usageCount
}

module.exports = {
    postUsage
}
