const {checkAuthentication, checkPrivileges} = require('../../utils/validateUser');
const RequestError = require('requesterror');
const isValidUUID = require('../../utils/validUUID');
const {find_by_id} = require('../../customerOrderDB');

const handleGetCust = ({customer_id, authHeader, type = 'user'}) => {
    const authenticated = checkAuthentication(authHeader);
    if (checkAuthentication(authHeader) instanceof Error) {
        return authenticated;
    }

    const correctPrivileges = checkPrivileges(authHeader, type);
    if (correctPrivileges instanceof Error) {
        return correctPrivileges;
    }

    if (!isValidUUID(customer_id)) {
        return new RequestError(400, 'invalid_input', 'The customer ID is invalid', 'parameter');
    }

    const customer = getCustomer(customer_id)
    if (customer instanceof Error) {
        return customer
    }

    return ({
        code: 200,
        customer: customer
    });
}

const getCustomer = customerID => {
    const randomNo = Math.floor(Math.random() * 101);

    if (randomNo === 48) {
        return new RequestError(500, 'retrieve_failed', 'The server was unable to retrieve the customer details', 'Internal Server Error');
    }

    const customer = find_by_id('customers', customerID)
    if (customer === undefined) {
        return new RequestError(404, 'not_found', 'The customer could not be located', 'parameter');
    }
    return customer;
}

module.exports = handleGetCust;