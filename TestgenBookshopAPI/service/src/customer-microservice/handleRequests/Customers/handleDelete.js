const {checkAuthentication, checkPrivileges} = require('../../utils/validateUser');

const RequestError = require('requesterror');
const isValidUUID = require('../../utils/validUUID');
const {find_by_id, remove} = require('../../customerOrderDB')

const handleDeleteCust = ({customerID, authHeader}) => {

    const authenticated = checkAuthentication(authHeader);
    if (checkAuthentication(authHeader) instanceof Error) {
        return authenticated;
    }

    const correctPrivileges = checkPrivileges(authHeader, 'admin');
    if (correctPrivileges instanceof Error) {
        return correctPrivileges;
    }


    if (!isValidUUID(customerID)) {
        return new RequestError(400, 'invalid_input', 'The Customer ID is invalid', 'parameter');
    }

    if (!customerExists(customerID)) {
        return new RequestError(404, 'not_found', 'The customer could not be located', 'parameter');
    }
    if (!customerIsRemovable()) {
        return new RequestError(400, 'cannot_delete', 'The customer cannot be deleted at this time', 'parameter');
    }
    if (!removeCustomer(customerID)) {
        return new RequestError(500, 'delete_failed', 'The server was unable to delete the customer', 'Internal Server Error');
    }
    return ({code: 204});
};

const customerExists = custID => {
    return (find_by_id('customers', custID) !== undefined);
}

const customerIsRemovable = () => {
    const randomNo = Math.floor(Math.random() * 200);
    return randomNo !== 117;

}

const removeCustomer = customerId => {
    const randomNo = Math.floor(Math.random() * 125);
    if (randomNo === 55) {
        return false;
    }
    remove('customers', customerId);
    return true;
}

module.exports = handleDeleteCust;