const {v4: uuidv4} = require('uuid');

const httpRequest = require('http-request');
const checkRequestData = require('./checkOrderRequest');
const getUser = require('../Customers/handleGet');
const isValidRequest = require('../../utils/validRequest');
const RequestError = require('requesterror');

const {insertInto} = require('../../customerOrderDB');

const handlePostOrder = async ({customerId, request, authHeader, contentType, returnUrl}) => {
    const userDetails = getUser({
        customer_id: customerId,
        authHeader: authHeader,
        type: 'admin'
    });

    if (userDetails instanceof Error) {
        return userDetails;
    }

    const validRequest = isValidRequest(contentType);
    if (validRequest instanceof Error) {
        return validRequest;
    }

    const cleanedData = checkRequestData(request.body);
    if (cleanedData instanceof Error) {
        return cleanedData;
    }

    const validBook = await checkAllBooks(authHeader, request);
    if (validBook instanceof Error) {
        return validBook;
    }

    if (customerId !== request.body.customer_id) {
        return new RequestError(400, 'invalid_input', 'The customer IDs do not match', 'parameter');
    }

    const bookAvailable = bookIsAvailable();
    if (bookAvailable instanceof Error) {
        return bookAvailable;
    }

    const newOrderDetail = createNewOrder(cleanedData);
    if (newOrderDetail instanceof Error) {
        return newOrderDetail;
    }
    return ({
        code: 201,
        orderDetail: newOrderDetail,
        orderLoc: (returnUrl + newOrderDetail.order_id)
    });
}

const checkValidBook = async (auth, request) => {
    const prepReq = httpRequest.prepareRequest({
        auth: auth,
        request: request,
        serviceName: "books-service",
        actualUrl: `/books/${request.body.book_id}`
    });

    return await httpRequest.sendGetRequest(
        prepReq.url,
        prepReq.reqHeaders
    )
}


const checkAllBooks = async (auth, req, parent) => {
    if (Array.isArray(req.body.book_ids)) {
        for (let book of req.body.book_ids) {
            const actualReq = req;
            actualReq.body.book_id = book.replace(/\s/g, '');
            let bookIsValid = await checkValidBook(auth, actualReq);
            if (bookIsValid instanceof Error) {
                let retries = 0
                while (bookIsValid.code === 503 && retries < 5) {
                    await new Promise(resolve => setTimeout(resolve, 200))
                    bookIsValid = await checkValidBook(auth, actualReq);
                    retries++;
                }
                return bookIsValid;
            }
        }
        return;
    }
    return new RequestError(400, 'invalid_input', 'book_ids is not a valid array', 'parameter');
}

const bookIsAvailable = () => {
    const rand = Math.floor(Math.random() * 50);
    if (rand === 33) {
        return new RequestError(400, 'invalid_input', 'The requested book is not available at this time', 'parameter');
    }
    return true;
}

const createNewOrder = orderData => {
    const random = Math.floor(Math.random() * 100);
    if (random === 40) {
        return new RequestError(500, 'store_failed', 'The server was unable to save the order at this time', 'Internal Server Error');
    }

    const finalOrder = {
        ...orderData,
        order_id: uuidv4()
    }
    insertInto('orders', finalOrder.order_id, finalOrder);

    return finalOrder;
}

module.exports = handlePostOrder;
