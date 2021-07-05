const {v4: uuidv4} = require('uuid');

const RequestError = require('requesterror');
const {checkAuthentication, checkPrivileges} = require('../../utils/validateUser');
const checkDataValidity = require('./validateData');
const isValidRequest = require('../../utils/validRequest');

const httpRequest = require('http-request');

const {insert} = require('../../booksDB');

const handlePostBook = async ({rawRequest, authHeader, contentType, requestUrl}) => {

    if (!rawRequest.body.language || rawRequest.body.language === '') {
        return new RequestError(400, 'invalid_input', 'Language is a required field', 'field');
    }

    if (!/^[a-z]{2}/.test(rawRequest.body.language)) {
        return new RequestError(400, 'invalid_input', 'The language provided is not valid', 'parameter');
    }

    if (rawRequest.body.language.toLowerCase() !== process.env.LANGUAGE) {
        const languageList = process.env.ALL_LANGUAGES.split(" ");
        if (languageList.includes(rawRequest.body.language)) {
            const prepRequest = httpRequest.prepareRequest({
                auth: authHeader,
                request: rawRequest,
                serviceName: `${rawRequest.body.language}-books-service`
            });
            const response = await httpRequest.sendPostRequest(
                prepRequest.url,
                prepRequest.reqHeaders,
                rawRequest.body
            );
            if (response instanceof Error) {
                return response;
            }
            return ({
                code: 201,
                bookLocation: (requestUrl + response.data.book_id),
                book: response.data
            });
        }
    }

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

    const validData = checkDataValidity(rawRequest.body);
    if (validData !== true) {
        return validData;
    }

    // introduce asynchronous behaviour on client request
    var results
    const async = rawRequest.get('X-Bookshop-Async')
    if (async && async.toLowerCase() === 'true') {
        results = await Promise.all([
            getAuthorId(authHeader, rawRequest),
            getBookCategory(authHeader, rawRequest)
        ])
    } else {
        results = [
            await getAuthorId(authHeader, rawRequest),
            await getBookCategory(authHeader, rawRequest)
        ]
    }
    const authorId = results[0]
    if (authorId instanceof Error) {
        return authorId
    }
    const category = results[1]
    if (category instanceof Error) {
        return category
    }

    if (rawRequest.body.format.toLowerCase() === 'digital') {
        const bookCopied = copyBook();
        if (bookCopied !== true) {
            return bookCopied;
        }
    }

    const bookId = uuidv4()

    const finalBook = {
        ...extractAcceptedFields(rawRequest.body),
        book_id: bookId,
        author_id: authorId,
        category: category
    }
    const bookSaved = addBookToDatabase(finalBook);
    if (bookSaved) {
        return {
            code: 201,
            bookLocation: (requestUrl + bookId),
            book: finalBook
        };
    } else {
        return bookSaved;
    }
}

const extractAcceptedFields = (requestData) => {
    const acceptedFields = ['title', 'author', 'publisher', 'date', 'isbn', 'format', 'language', 'synopsis'];
    return Object.keys(requestData)
        .filter(current => acceptedFields.includes(current))
        .reduce((object, current) => {
            object[current] = requestData[current];
            return object;
        }, {});
}

const getAuthorId = async (authHeader, rawRequest) => {
    const body = {
        author: rawRequest.body.author
    }

    const ms = Math.floor(Math.random() * 100)
    await new Promise(resolve => setTimeout(resolve, ms))

    const prepRequest = httpRequest.prepareRequest({
        auth: authHeader,
        request: rawRequest,
        serviceName: 'bookshop-services',
        actualUrl: '/services/author'
    });

    const response = await httpRequest.sendPostRequest(
        prepRequest.url,
        prepRequest.reqHeaders,
        body
    );
    if (response instanceof Error) {
        // shouldn't happen
        return new RequestError(500, 'internal_error', 'The server was unable to process the request')
    }
    if (response.data.authors.length === 0) {
        return new RequestError(400, 'unknown', 'The author is unknown', 'parameter')
    }
    return response.data.authors[0].author_id
}

const getBookCategory = async (authHeader, rawRequest) => {
    const body = {
        title: rawRequest.body.title,
        synopsis: rawRequest.body.synopsis
    }

    const ms = Math.floor(Math.random() * 100)
    await new Promise(resolve => setTimeout(resolve, ms))

    const prepRequest = httpRequest.prepareRequest({
        auth: authHeader,
        request: rawRequest,
        serviceName: 'bookshop-services',
        actualUrl: '/services/category'
    });

    const response = await httpRequest.sendPostRequest(
        prepRequest.url,
        prepRequest.reqHeaders,
        body
    );
    if (response instanceof Error) {
        // shouldn't happen
        return new RequestError(500, 'internal_error', 'The server was unable to process the request')
    }
    return (response.data.categories.length === 0) ? "" : response.data.categories[0]
}

const copyBook = () => {
    const randomNo = Math.floor(Math.random() * 100);
    if (randomNo === 57) {
        return new RequestError(500, 'copy_failed', 'The server was unable to obtain the digital content', 'parameter');
    }
    return true;
}

const addBookToDatabase = book => {
    const randomNo = Math.floor(Math.random() * 100);
    if (randomNo === 37) {
        return new RequestError(500, 'store_failed', 'The server was unable to save the book details', 'parameter');
    } else {
        insert(book.book_id, book);
        return true;
    }
}

module.exports = handlePostBook;
