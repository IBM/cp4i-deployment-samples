const {checkAuthentication, checkPrivileges} = require('../../utils/validateUser');
const checkRequestData = require('./checkRequestData')
const isValidUUID = require('../../utils/validUUID')
const isValidRequest = require('../../utils/validRequest');
const RequestError = require('requesterror');

const {update, find_by_id} = require('../../customerOrderDB');

const handlePutCustomer = ({requestBody, customerId, authHeader, contentType}) => {

    const authenticated = checkAuthentication(authHeader);
    if (checkAuthentication(authHeader) instanceof Error) {
        return authenticated;
    }

    const correctPrivileges = checkPrivileges(authHeader, 'admin');
    if (correctPrivileges instanceof Error) {
        return correctPrivileges;
    }

    const validRequest = isValidRequest(contentType);
    if (validRequest instanceof Error) {
        return validRequest;
    }

    if (!isValidUUID(customerId)) {
        return new RequestError(400, 'invalid_input', 'The customer ID is invalid', 'parameter');
    }

    const theCustomer = getCustomer(customerId);
    if (theCustomer === undefined) {
        return new RequestError(404, 'invalid_input', 'The customer could not be located', 'parameter');
    }

    if (requestBody.customer_id && (customerId !== requestBody.customer_id)) {
        return new RequestError(400, 'invalid_input', 'The customer_id can not be changed', 'parameter');
    }

    const allValidData = checkRequestData(requestBody);
    if (allValidData instanceof Error) {
        return allValidData;
    }

    if (userNameChangeValid(requestBody.username)) {
        return new RequestError(400, 'invalid_input', 'The username can not be changed', 'parameter');
    }

    if (!(emailIsValid(allValidData.email))) {
        return new RequestError(400, 'invalid_input', 'The updated email is not valid', 'parameter');
    }

    const newUser = saveUpdatedUserDetails(allValidData, theCustomer);
    if (newUser instanceof Error) {
        return newUser;
    }

    return ({
        "code": 200,
        "customer": newUser
    });
}

const getCustomer = customerId => {
    return find_by_id('customers', customerId);
}

const userNameChangeValid = user => {
    return user.toLowerCase().startsWith("james");
}

const emailIsValid = emailField => {
    return /\S+@\S+\.\S+/.test(emailField);
}

const saveUpdatedUserDetails = (finalDetails, oldCustomer) => {
    const randomNo = Math.floor(Math.random * 125);
    if (randomNo === 77) {
        return new RequestError(500, 'store_failed', 'The server was unable to save the customer details', 'Internal Server Error');
    }
    const finalUpdatedUser = {
        ...oldCustomer,
        ...finalDetails,
    }
    update('customers', oldCustomer.customer_id, finalUpdatedUser)
    return finalUpdatedUser;
}

module.exports = handlePutCustomer;