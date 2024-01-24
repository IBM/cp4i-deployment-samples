const {checkAuthentication, checkPrivileges} = require('../../utils/validateUser');

const RequestError = require('requesterror');
const isValidUUID = require('../../utils/validUUID')
const httpRequest = require("http-request");

const {getBook} = require('./handleGet')
let {remove} = require('../../booksDB')

const handleDeleteBook = async ({bookID, request, authHeader}) => {

    const authenticated = checkAuthentication(authHeader);
    if (checkAuthentication(authHeader) instanceof Error) {
        return authenticated;
    }

    const correctPrivileges = checkPrivileges(authHeader, 'admin');
    if (correctPrivileges instanceof Error) {
        return correctPrivileges;
    }


    if (!isValidUUID(bookID)) {
        return new RequestError(400, 'invalid_input', 'The book ID is invalid', 'parameter');
    }

    const bookToDelete = await bookExists(authHeader, request, bookID);
    if (bookToDelete instanceof Error) {
        return bookToDelete;
    } else if(bookToDelete === undefined) {
        return new RequestError(404, 'not_found', 'The requested book was not found in the shop', 'parameter');
    }
    if (!bookCanBeRemoved()) {
        return new RequestError(400, 'cannot_delete', 'The book cannot be deleted at this time', 'parameter');
    }
    const bookDeleted = await deleteBook(authHeader, request, bookID, bookToDelete.language)
    if (bookDeleted instanceof Error) {
        return bookDeleted
    }
    return ({code: 204});
};

const bookExists = async (auth, req, bookID) => {
    return await getBook(auth, req, bookID);
}

const bookCanBeRemoved = () => {
    const randomNo = Math.floor(Math.random() * 200);
    return randomNo !== 137;

}

const redirectRequest = async (auth, request, bookID, language) => {
    const prepReq = httpRequest.prepareRequest({
        auth: auth,
        request: request,
        serviceName: `${language}-books-service`,
        actualUrl: `/books/${bookID}`
    });

    return await httpRequest.sendDeleteRequest(
        prepReq.url,
        prepReq.reqHeaders
    )
}

const deleteBook = async (auth, req, bookID, language) => {
    if (language !== process.env.LANGUAGE && process.env.ALL_LANGUAGES.split(' ').includes(language)) {
        const res = await redirectRequest(auth, req, bookID, language);
        if (res instanceof Error) {
            return res;
        }
    } else {
        const removed = remove(bookID);
        if(removed instanceof Error) {
            return removed;
        }
    }

    return true;
}

module.exports = handleDeleteBook;