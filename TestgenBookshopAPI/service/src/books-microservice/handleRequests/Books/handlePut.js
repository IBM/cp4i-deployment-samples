const {checkAuthentication, checkPrivileges} = require('../../utils/validateUser');

const RequestError = require('requesterror');

const checkDataValidity = require('./validateData');
const isValidUUID = require('../../utils/validUUID')
const isValidRequest = require('../../utils/validRequest');
const httpRequest = require('http-request');

const {getBook} = require('./handleGet');
const {update} = require('../../booksDB')

const handlePutBook = async ({rawRequest, bookID, authHeader, contentType}) => {

    if(!rawRequest.body.language || rawRequest.body.language === '') {
        return new RequestError(400, 'invalid_input', 'Language is a required field', 'field');
    }

    if(!/^[a-z]{2}/.test(rawRequest.body.language)) {
        return new RequestError(400, 'invalid_input', 'The language provided is not valid', 'parameter');
    }

    if(rawRequest.body.language.toLowerCase() !== process.env.LANGUAGE) {
        const languageList = process.env.ALL_LANGUAGES.split(" ");
        if(languageList.includes(rawRequest.body.language)) {
            const prepRequest = httpRequest.prepareRequest({
                auth: authHeader,
                request: rawRequest,
                serviceName: `${rawRequest.body.language}-books-service`
            });

            const bookRes = await httpRequest.sendPutRequest(
                prepRequest.url,
                prepRequest.reqHeaders,
                rawRequest.body
            );

            if(bookRes instanceof Error) {
                return bookRes;
            }

            return ({
                code: 200,
                book: bookRes.data.book
            });
        }
    }

    const authenticated = checkAuthentication(authHeader);
    if(checkAuthentication(authHeader) instanceof Error) {
        return authenticated;
    }

    const correctPrivileges = checkPrivileges(authHeader, 'admin');
    if(correctPrivileges instanceof Error) {
        return correctPrivileges;
    }

    const validRequest = isValidRequest(contentType);
    if(validRequest instanceof Error) {
        return validRequest;
    }

    if(!isValidUUID(bookID)) {
        return new RequestError(400, 'invalid_input', 'The book ID is invalid', 'parameter');
    }

    const validData = checkDataValidity(rawRequest.body, true);
    if(validData !== true) {
        return validData;
    }

    const checkID = checkBookID(rawRequest.body, bookID);
    if(!checkID) {
        return new RequestError(400, 'bad_request', 'Book ID param does not match the specified ID', 'field');
    }

    const checkBookExists = bookExists(bookID);
    if(checkBookExists) {
        return new RequestError(404, 'not_found', 'The requested book was not found in the shop', 'parameter');
    }

    const theBook = await findBook(authHeader, rawRequest, bookID);
    if(theBook instanceof Error) {
        return theBook;
    }

    const checkValidAuthor = validAuthorChange(rawRequest.body);
    if(!checkValidAuthor) {
        return new RequestError(400, 'invalid_update', 'The author of a book cannot be changed', 'field');
    }

    const isbnChanged = validISBNChange(rawRequest.body);
    if(!isbnChanged) {
        return new RequestError(400, 'invalid_update', 'The ISBN of a book cannot be changed', 'field');
    }

    const newBook = storeUpdatedBook(theBook, rawRequest.body);
    if(newBook instanceof Error) {
        return newBook;
    }

    return ({
        "code" : 200,
        "book" : newBook
    });
}

const checkBookID = (request, id) => {
    if(request.book_id === undefined) {
        return true;
    }
    return (request.book_id === id);
}

const bookExists = id => {
    return (id.includes("3ac"));
}

const findBook = async (auth, request, bookID) => {
    const randomNo = Math.floor(Math.random() * 101);
    if(randomNo === 39) {
        return new RequestError(500, 'retrieve_failed', 'The server was unable to retrieve the book details', 'Internal Server Error');
    }

    return await getBook(auth, request, bookID);
}

const validAuthorChange = requestData => {
    if(requestData.author === undefined) {
        return true;
    }
    return !requestData.author.toLowerCase().startsWith("james");

}

const validISBNChange = requestData => {
    if(requestData.isbn === undefined) {
        return true;
    }
    return !requestData.isbn.includes("92");

}

const storeUpdatedBook = (oldBook, newBook) => {
    const finalUpdatedBook = extractAcceptedFields(newBook);
    const theBook = {
        ...oldBook,
        ...finalUpdatedBook
    };

    const randomNo = Math.floor(Math.random() * 101);
    if(randomNo === 59) {
        return new RequestError(500, 'store_failed', 'The server was unable to save the book details', 'Internal Server Error');
    }
    update(theBook.book_id, theBook);
    return theBook;
}

const extractAcceptedFields = (requestData) => {
    const acceptedFields = ['title', 'author', 'publisher', 'date', 'isbn', 'format', 'synopsis'];
    return Object.keys(requestData)
        .filter(current => acceptedFields.includes(current))
        .reduce((object, current) => {
            object[current] = requestData[current];
            return object;
        }, {});
}

module.exports = handlePutBook;
