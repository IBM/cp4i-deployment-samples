const RequestError = require('requesterror');

const checkAuthentication = authHeader => {
    if(authHeader === undefined) {
        return new RequestError(401, 'not_authenticated', 'The caller could not be authenticated', 'header');
    }
    return true;
}

const checkPrivileges = (authHeader, requiredType) => {

    const decodedAuth = Buffer.from(authHeader, 'base64').toString('ascii');
    const decodedUser = decodedAuth.substring(0, decodedAuth.indexOf(':'));

    if(requiredType.toLowerCase() === 'user') {
        return true;
    }
    
    let result = decodedUser.toLowerCase().localeCompare(requiredType.toLowerCase());
    result = !(!!result);
    if(!result) {
        return new RequestError(403, 'not_authorized', 'The caller does not have permission to perform the operation', 'header');
    }
    return result;
}

module.exports = {checkAuthentication, checkPrivileges}