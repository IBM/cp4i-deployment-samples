const restclient = require('../utils/restclient')

const usageUrl = process.env.USAGE_SERVICE_URL || 'http://localhost:5000/services/usage'

async function recordUsage(req, service) {
    const auth = req.get('Authorization')
    const body = {
        service: service
    }
    const options = {
        axios: {
            validateStatus: (status) => {
                return status == 200
            }
        },
        trace: {
            span: req.span,
            operation: 'record_usage'
        }
    }
    return restclient.post(usageUrl, auth, body, options)
}

module.exports = recordUsage
