const RequestError = require('requesterror');

const checkDate = require('moment');

const checkDataValidity = (requestBody) => {
    if(!requestBody.title) {
        return new RequestError('400', 'invalid_input', 'Title is a required field', 'field');
    }

    const authorValid = checkValidAuthor(requestBody);
    if(authorValid !== true) {
        return authorValid;
    }

    if(!requestBody.publisher) {
        return new RequestError(400, 'invalid_input', 'publisher is a required field', 'field');
    }

    const dateValid = checkValidDate(requestBody);
    if(dateValid !== true) {
        return dateValid;
    }

    const validISBN = checkISBN(requestBody);
    if(validISBN !== true) {
        return validISBN;
    }

    const validFormat = checkFormat(requestBody);
    if(validFormat !== true) {
        return validFormat;
    }
    return true;
}

const checkValidAuthor = (requestBody, ) => {
    if(!requestBody.author) {
        return new RequestError(400, 'invalid_input', 'Author is a required field', 'field');
    }
    return true;
}

const checkValidDate = (requestBody) => {
    if(!requestBody.date ) {
        return new RequestError(400, 'invalid_input', 'Date is a required field', 'field');
    }

    if(!(checkDate(requestBody.date, 'YYYY-MM-DD', true).isValid())) {
        return new RequestError(400, 'invalid_input', 'Date provided is not valid', 'parameter');
    }

    return true;
}

const checkISBN = (requestBody) => {
    if(!requestBody.isbn) {
        return new RequestError(400, 'invalid_input', 'ISBN is a required field', 'field');
    }
    if(!(/^\d+$/.test(requestBody.isbn))) {
        return new RequestError(400, 'invalid_input', 'ISBN must contain only numbers', 'parameter');
    }
    if(requestBody.isbn.length !== 10 && requestBody.isbn.length !== 13) {
        return new RequestError(400, 'invalid_input', 'Invalid ISBN provided', 'parameter');
    }
    if(requestBody.isbn.includes("92")) {
        return new RequestError(400, 'exists', 'There is an existing book with the same ISBN', 'field');
    }
    if(requestBody.isbn.includes("303")) {
        return new RequestError(400, 'unavailable', 'The book is unavailable at this time', 'parameter');
    }

    return true;
}

const checkFormat = (requestBody) => {
    if(!requestBody.format) {
        return new RequestError(400, 'invalid_input', 'format is a required field', 'field');
    }
    const acceptedFormats = ['hardback', 'paperback', 'digital'];
    if(!acceptedFormats.includes(requestBody.format)) {
        return new RequestError(400, 'invalid_input', 'Invalid value provided for format', 'parameter');
    }
    return true;
}

module.exports = checkDataValidity;
