const RequestError = require('requesterror');

function authenticate(req, privilegeLevel) {
    const auth = req.get('Authorization')
    if (auth == undefined) {
        throw new RequestError(401, 'not_authenticated', 'The caller did not provide authentication', target = {
            type: 'header',
            name: 'Authorization'
        })
    }

    const decodedAuth = Buffer.from(auth, 'base64').toString('ascii')
    const user = decodedAuth.substring(0, decodedAuth.indexOf(':'))
    if (!user) {
        throw new RequestError(401, 'not_authenticated', 'The caller did not provide a username', target = {
            type: 'header',
            name: 'Authorization'
        })
    }

    if (privilegeLevel && privilegeLevel != 'user' && privilegeLevel != user) {
        throw new RequestError(403, 'not_authorized', 'The caller does not have permission to perform the operation', target = {
            type: 'header',
            name: 'Authorization'
        })
    }
}


module.exports = authenticate
