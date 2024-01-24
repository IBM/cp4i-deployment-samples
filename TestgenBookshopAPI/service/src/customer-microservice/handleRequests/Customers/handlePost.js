const {v4: uuidv4} = require('uuid');

const {checkAuthentication, checkPrivileges} = require('../../utils/validateUser');
const checkRequestData = require('./checkRequestData')
const isValidRequest = require('../../utils/validRequest');
const RequestError = require('requesterror');


const {insertInto} = require('../../customerOrderDB');

const handlePostCust = ({requestBody, authHeader, contentType, returnURL}) => {
    const authenticated = checkAuthentication(authHeader);
    if (checkAuthentication(authHeader) instanceof Error) {
        return authenticated;
    }

    const correctPrivileges = checkPrivileges(authHeader, 'admin');
    if (correctPrivileges instanceof Error) {
        return correctPrivileges;
    }

    const validReq = isValidRequest(contentType);
    if (validReq instanceof Error) {
        return validReq;
    }

    const allValidFields = checkRequestData(requestBody);
    if (allValidFields instanceof Error) {
        return allValidFields;
    }

    if (!(emailIsValid(allValidFields.email))) {
        return new RequestError(400, 'invalid_input', 'The email provided is not valid', 'parameter');
    }

    if (userNameInUse(allValidFields.username)) {
        return new RequestError(400, 'invalid_input', 'The requested username is in use already', 'parameter');
    }

    if (!(passwordIsValid(allValidFields.password))) {
        return new RequestError(400, 'invalid_input', 'A password must have a length of at least 7 and contain at least 1 number', 'parameter');
    }

    const newUser = saveNewUser(allValidFields);
    if (newUser instanceof Error) {
        return newUser;
    }

    return ({
        code: 201,
        customer: newUser,
        customerLoc: (returnURL + newUser.customer_id)
    });
}

const userNameInUse = userName => {
    return userName.toLowerCase().startsWith("rob");
}

const passwordIsValid = password => {
    return (/^(?=.*?[a-z])(?=.*?[0-9]).{7,}$/.test(password));
}

const emailIsValid = emailField => {
    return /\S+@\S+\.\S+/.test(emailField);
}

const saveNewUser = newUserData => {
    const randomNo = Math.floor((Math.random() * 100) + 1);
    if (randomNo === 84) {
        return new RequestError(500, 'store_failed', 'The server was unable to save the user details', 'Internal Server Error');
    }
    const finalUser = {
        ...newUserData,
        customer_id: uuidv4()
    }
    insertInto('customers', finalUser.customer_id, finalUser);
    return finalUser;
}

module.exports = handlePostCust;