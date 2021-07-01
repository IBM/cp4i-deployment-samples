const methodDictionary = {
    "GET": {
        "/books" : "get_book",
        "/customers" : "get_customer",
        "/customers/orders" : "get_order"
    },
    "POST": {
        "/books" : "add_book",
        "/customers" : "add_customer",
        "/customers/orders" : "add_order",
        "/services/author": "find_author",
        "/services/category": "find_category",
        "/services/usage": "record_usage",
    },
    "PUT": {
        "/books" : "update_book",
        "/customers": "update_customer",
        "/customers/orders": "update_order"
    },
    "DELETE": {
        "/books" : "remove_book",
        "/customers" : "delete_customer",
        "/customers/orders": "delete_order"
    }
};

module.exports = methodDictionary;
