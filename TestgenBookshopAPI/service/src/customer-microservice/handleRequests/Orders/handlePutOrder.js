const {checkAuthentication, checkPrivileges} = require('../../utils/validateUser');
const httpRequest = require('http-request');
const isValidUUID = require('../../utils/validUUID')
const isValidRequest = require('../../utils/validRequest');
const getValidFields = require('./checkOrderRequest');
const RequestError = require('requesterror');

const {find_by_id, update} = require('../../customerOrderDB');

const handlePutOrder = async ({request, customerId, orderId, authHeader, contentType}) => {
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

    const customerValid = validateCustomer(customerId);
    if (customerValid instanceof Error) {
        return customerValid;
    }

    const validOrder = validateOrder(orderId);
    if (validOrder instanceof Error) {
        return validOrder;
    }

    const updatedFields = getValidFields(request.body);
    if (updatedFields instanceof Error) {
        return updatedFields;
    }

    if (request.body.customer_id && (request.body.customer_id !== customerId)) {
        return new RequestError(400, 'invalid_input', 'The customer this order is associated with can not be changed', 'parameter');
    }

    if (request.body.order_id !== orderId) {
        return new RequestError(400, 'invalid_input', 'The order ID can not be changed', 'parameter');
    }

    const bookValid = await checkAllBooks(authHeader, request);
    if (bookValid instanceof Error) {
        return bookValid;
    }

    const orderDetails = getOrderDetails(customerId, orderId);
    if (orderDetails instanceof Error) {
        return orderDetails;
    }

    const validUpdate = checkUpdateIsValid(updatedFields, orderDetails);
    if (validUpdate instanceof Error) {
        return validUpdate;
    }

    const savedOrder = saveNewOrder(orderDetails, updatedFields);
    if (savedOrder instanceof Error) {
        return savedOrder;
    }

    return ({
        code: 200,
        updatedOrder: savedOrder
    });
}

const validateCustomer = customer => {
    if (!(isValidUUID(customer))) {
        return new RequestError(400, 'invalid_input', 'The customer ID is invalid', 'parameter');
    }
    if (customer.includes("4ab")) {
        return new RequestError(404, 'not_found', 'The customer could not be located', 'parameter');
    }
    return true;
}

const bookIsValid = async (request, auth, bookId) => {
    const prepRequest = httpRequest.prepareRequest({
        auth: auth,
        request: request,
        serviceName: "books-service",
        actualUrl: `/books/${bookId}`
    });

    return await httpRequest.sendGetRequest(
        prepRequest.url,
        prepRequest.reqHeaders
    );

}


const checkAllBooks = async (auth, req) => {
    if(Array.isArray(req.body.book_ids)) {
        for(let book of req.body.book_ids) {
            let bookValid = await bookIsValid(req, auth, book.replace(/\s/g, ''));
            if (bookValid instanceof Error) {
                let retries = 0
                while (bookValid.code === 503 && retries < 5) {
                    await new Promise(resolve => setTimeout(resolve, 200))
                    bookValid = await bookIsValid(auth, req, book.replace(/\s/g, ''));
                    retries++;
                }
                return bookValid;
            }
        }
        return;
    }
    return new RequestError(400, 'invalid_input', 'book_ids is not a valid array', 'parameter');
}

const validateOrder = orderId => {
    if (!(isValidUUID(orderId))) {
        return new RequestError(400, 'invalid_input', 'The order ID is invalid', 'parameter');
    }
    return true;
}

const getOrderDetails = (customerId, orderId) => {

    const randomNo = Math.floor(Math.random() * 100);
    if(randomNo === 88) {
        return new RequestError(500, 'retrieve_failed', 'The server was unable to retrieve the order details', 'Internal Server Error');
    }
    const order = find_by_id('orders', orderId);
    if (order === undefined) {
        return new RequestError(404, 'not_found', 'The requested order could not be located', 'parameter');
    }
    if (order.customer_id !== customerId) {
        return new RequestError(400, 'invalid_input', 'This order is not associated with the specified customer', 'parameter');
    }
    return order;
}

const checkUpdateIsValid = (newOrder, oldOrder) => {
    if(oldOrder.quantity !== newOrder.quantity) {
        if((newOrder.quantity % 5) === 0) {
            return new RequestError(400, 'invalid_input', 'The requested quantity can not be fulfilled', 'parameter');
        }
    }
}

const saveNewOrder = (oldOrder, newOrder) => {
    const randomNo = Math.floor(Math.random() * 125);
    if(randomNo === 66) {
        return new RequestError(500, 'store_failed', 'The server was unable to save the updated order details', 'Internal Server Error');
    }
    const finalOrder = {
        ...oldOrder,
        ...newOrder
    }
    update('orders', oldOrder.order_id, finalOrder);

    return finalOrder;
}

module.exports = handlePutOrder;
