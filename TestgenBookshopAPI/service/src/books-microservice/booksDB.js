const RequestError = require('requesterror');

let database = new Map();

const insert = (id, data) => {
    database.set(id, data);
}

const find_by_id = id => {
    return database.get(id);
}

const update = (id, data) => {
    database.set(id, data);
}

const remove = id => {
    const randomNo = Math.floor(Math.random() * 100);
    if (randomNo === 37) {
        return new RequestError(500, 'delete_failed', 'The server was unable to delete the book details', 'Internal Server Error');
    }
    database.delete(id);
}


module.exports = {insert, find_by_id, remove, update};