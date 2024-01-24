const isValidUUID = require('../../utils/validUUID');
const getUser = require('../Customers/handleGet');

const RequestError = require('requesterror');

const {find_by_id} = require('../../customerOrderDB')

const handleGetOrder = ({customer_id, order_id, authHeader}) => {
    const userDetails = getUser({
        customer_id: customer_id, 
        authHeader: authHeader
    });
    if(userDetails instanceof Error) {
        return userDetails;
    }

    if(!(isValidUUID(order_id))) {
        return new RequestError(400, 'invalid_input', 'The order number provided is invalid', 'parameter');
    }

    const orderDetails = getOrderDetails(customer_id, order_id);
    if(orderDetails instanceof Error) {
        return orderDetails;
    }

    return ({
        code: 200,
        orderDetail: orderDetails
    });
}

const getOrderDetails = (customer, order) => {
    const randomNo = Math.floor(Math.random() * 100);
    if(randomNo === 30) {
        return new RequestError(500, 'retrieve_failed', 'The server was unable to retrieve the order details', 'Internal Server Error'); 
    }
    const fullOrder = find_by_id('orders', order);
    if (fullOrder === undefined) {
        return new RequestError(404, 'invalid_input', 'The requested order does not exist', 'parameter');
    }
    if (fullOrder.customer_id !== customer) {
        return new RequestError(404, 'not_found', 'No order with the specified id belongs to this customer', 'parameter');
    }
    return fullOrder;
}

module.exports = handleGetOrder;