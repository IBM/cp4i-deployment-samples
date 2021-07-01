const RequestError = require('requesterror');

const checkRequestData = requestBody => {
    const acceptedFields = ['username', 'first_name', 'last_name', 'email', 'password', 'phone'];
    const actualInput = Object.keys(requestBody)
        .filter(current => acceptedFields.includes(current))
        .reduce((object, current) => {
            object[current] = requestBody[current];
            return object;
        }, {} );

    if(!actualInput.username || actualInput.userName === '') {
        return new RequestError(400, 'invalid_input', 'username is a required field', 'field');
    }
    if(!actualInput.first_name || actualInput.first_name === '') {
        return new RequestError(400, 'invalid_input', 'first name is a required field', 'field');
    }
    if(!actualInput.last_name || actualInput.last_name === '') {
        return new RequestError(400, 'invalid_input', 'last name is a required field', 'field');
    }
    if(!actualInput.password || actualInput.password === '') {
        return new RequestError(400, 'invalid_input', 'password is a required field', 'field');
    }
    if(!actualInput.email || actualInput.email === '') {
        return new RequestError(400, 'invalid_input', 'email is a required field', 'field');
    }

    return actualInput;
}

module.exports = checkRequestData;