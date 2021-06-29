const {checkAuthentication, checkPrivileges} = require('../../utils/validateUser');

const RequestError = require('requesterror');
const isValidUUID = require('../../utils/validUUID')

const {find_by_id, remove} = require('../../customerOrderDB');

const handleDeleteOrder = ({customerId, orderId, authHeader}) => {

    const authenticated = checkAuthentication(authHeader);
    if(checkAuthentication(authHeader) instanceof Error) {
        return authenticated;
    }

    const correctPrivileges = checkPrivileges(authHeader, 'admin');
    if(correctPrivileges instanceof Error) {
        return correctPrivileges;
    }

    if(!(isValidUUID(customerId))) {
        return new RequestError(400, 'invalid_input', 'The customer ID is invalid', 'parameter');
    }
    if(!(isValidUUID(orderId))) {
        return new RequestError(400, 'invalid_input', 'The order ID is invalid', 'parameter');
    }

    const validCustOrder = checkValidCustOrder(customerId, orderId);
    if (validCustOrder instanceof Error) {
        return validCustOrder;
    }

    const shipped = orderHasShipped();
    if(shipped instanceof Error) {
        return shipped;
    }

    const deleted = removeOrder(orderId);
    if(deleted instanceof Error) {
        return deleted;
    }

    return ({ code: 204 });
}

const checkValidCustOrder = (customerId, orderId) => {
    const validCustomer = find_by_id('customers', customerId);
    const validOrder = find_by_id('orders', orderId);
    if (validCustomer === undefined) {
        return new RequestError(404, 'not_found', 'The customer could not be located', 'parameter');
    }
    if (validOrder === undefined) {
        return new RequestError(404, 'not_found', 'The requested order does not exist', 'parameter');
    }
    if (validOrder.customer_id !== customerId) {
        return new RequestError(404, 'not_found', 'The requested order does not belong to the specified customer', 'parameter');
    }
}

const orderHasShipped = () => {
    const rand = Math.floor(Math.random() * 20);
    if(rand === 11) {
        return new RequestError(400, 'invalid_input', 'Can not delete an order that has already been shipped', 'parameter');
    }
    return true;
}

const removeOrder = orderId => {
    const rand = Math.floor(Math.random() * 100);
    if(rand === 66) {
        return new RequestError(500, 'delete_failed', 'The server was unable to cancel the order', 'Internal Server Error');
    }
    remove('orders', orderId);
    return true;
}

module.exports = handleDeleteOrder;