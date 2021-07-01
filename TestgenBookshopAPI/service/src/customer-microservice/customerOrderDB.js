let Customers = new Map();
let Orders = new Map();

const insertInto = (table, id, data) => {
    if (table.toLowerCase() === 'customers') {
        Customers.set(id, data);
    } else {
        Orders.set(id, data);
    }
}

const find_by_id = (table, id) => {
    if (table.toLowerCase() === 'customers') {
        return Customers.get(id)
    } else {
        return Orders.get(id)
    }
}

const update = (table, id, data) => {
    if (table.toLowerCase() === 'customers') {
        Customers.set(id, data);
    } else {
        Orders.set(id, data);
    }
}

const remove = (table, id) => {
    if (table.toLowerCase() === 'customers') {
        Customers.delete(id)
    } else {
        Orders.delete(id);
    }
}


module.exports = {insertInto, find_by_id, remove, update};