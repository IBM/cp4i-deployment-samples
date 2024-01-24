const RequestError = require('requesterror');

const checkOrderRequestData = requestBody => {
    const acceptedFields = ['customer_id', 'book_ids', 'quantity', 'ship_date', 'status', 'complete'];
    const cleanedInput = Object.keys(requestBody)
        .filter(current => acceptedFields.includes(current))
        .reduce((object, current) => {
            object[current] = requestBody[current];
            return object;
        }, {} );

    if(!cleanedInput.customer_id || cleanedInput.customer_id === '') {
        return new RequestError(400, 'invalid_input', 'customer_id is a required field', 'field');
    }
    if(!cleanedInput.book_ids) {
        return new RequestError(400, 'invalid_input', 'book_ids is a required field', 'field');
    }
    if (cleanedInput.quantity === null) {
        return new RequestError(400, 'invalid_input', 'quantity is a required field', 'field');
    }
    if (!(Number.isInteger(cleanedInput.quantity) && cleanedInput.quantity > 0)) {
        return new RequestError(400, 'invalid_input', 'quantity must be an integer > 0', 'field');
    }

    return cleanedInput;
}

module.exports = checkOrderRequestData;
