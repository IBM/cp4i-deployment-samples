const express = require('express');
const router = express.Router();

const handleGetCustomer = require('../handleRequests/Customers/handleGet');
const handlePostCustomer = require('../handleRequests/Customers/handlePost');
const handleDeleteCustomer = require('../handleRequests/Customers/handleDelete');
const handlePutCustomer = require('../handleRequests/Customers/handlePut');

const handleGetOrder = require('../handleRequests/Orders/handleGetOrder');
const handlePostOrder = require('../handleRequests/Orders/handlePostOrder');
const handlePutOrder = require('../handleRequests/Orders/handlePutOrder');
const handleDeleteOrder = require('../handleRequests/Orders/handleDeleteOrder');

router.get('/customers/:customerID', (req, res) => {
    const response = handleGetCustomer({
        'customer_id': req.params.customerID, 
        'authHeader': req.get('Authorization')
    });

    const authFailed = response.code === 401 ? {"WWW-Authenticate": 'Access to this resource requires authentication'} : undefined

    if(response instanceof Error) {
        res.set(authFailed).status(response.code).json({
            code: response.code,
            message: response.message,
            target: {
                type: response.target,
                name: response.reason
            }
        });
    } else {
        res.status(response.code).json({
            customer: response.customer
        })
    }
});

router.post('/customers', (req, res) => {
    const url = req.protocol + "://" + req.get("host") + req.originalUrl + "/";
    const response = handlePostCustomer({
        'requestBody': req.body, 
        'authHeader': req.get('Authorization'),
        'contentType': req.get('Content-Type'),
        'returnURL': url
    });

    const authFailed = response.code === 401 ? {"WWW-Authenticate": 'Access to this resource requires authentication'} : undefined

    if(response instanceof Error) {
        res.set(authFailed).status(response.code).json({
            code: response.code,
            message: response.message,
            target: {
                type: response.target,
                name: response.reason
            }
        });
    } else {
        res.status(response.code)
            .set("Location", response.customerLoc)
            .json({
                customer: response.customer
            })
    }
});

router.delete('/customers/:customer_id', (req, res) => {
    const response = handleDeleteCustomer({
        'customerID': req.params.customer_id, 
        'authHeader': req.get('Authorization')
    });
    
    const authFailed = response.code === 401 ? {"WWW-Authenticate": 'Access to this resource requires authentication'} : undefined

    if(response instanceof Error) {
        res.set(authFailed).status(response.code).json({
            code: response.code,
            message: response.message,
            target: {
                type: response.target,
                name: response.reason
            }
        });
    } else {
        res.status(response.code).json({});
    }
});

router.put('/customers/:customer_id', (req, res) => {
    const response = handlePutCustomer({
        'requestBody': req.body, 
        'customerId': req.params.customer_id, 
        'authHeader': req.get('Authorization'),
        'contentType': req.get('Content-Type')
    });
    
    const authFailed = response.code === 401 ? {"WWW-Authenticate": 'Access to this resource requires authentication'} : undefined

    if(response instanceof Error) {
        res.set(authFailed).status(response.code).json({
            code: response.code,
            message: response.message,
            target: {
                type: response.target,
                name: response.reason
            }
        });
    } else {
        res.status(response.code).json({
            customer: response.customer
        })
    } 
});

router.get('/customers/:customer_id/orders/:order_id', (req, res) => {
    const response = handleGetOrder({
        'customer_id': req.params.customer_id,
        'order_id': req.params.order_id,
        'authHeader': req.get('Authorization')
    });

    const authFailed = response.code === 401 ? {"WWW-Authenticate": 'Access to this resource requires authentication'} : undefined

    if(response instanceof Error) {
        res.set(authFailed).status(response.code).json({
            code: response.code,
            message: response.message,
            target: {
                type: response.target,
                name: response.reason
            }
        });
    } else {
        res.status(response.code).json({
            order: response.orderDetail
        })
    }
});

router.post('/customers/:customerID/orders', async (req, res) => {
    const url = req.protocol + "://" + req.get("host") + req.originalUrl + "/";
    const response = await handlePostOrder({
        'customerId': req.params.customerID,
        'request': req,
        'authHeader': req.get('Authorization'),
        'contentType': req.get('Content-Type'),
        'returnUrl': url
    });
    
    const authFailed = response.code === 401 ? {"WWW-Authenticate": 'Access to this resource requires authentication'} : undefined

    if(response instanceof Error) {
        res.set(authFailed).status(response.code).json({
            code: response.code,
            message: response.message,
            target: {
                type: response.target,
                name: response.reason
            }
        });
    } else {
        res.status(response.code)
            .set("Location", response.orderLoc)
            .json({
                order: response.orderDetail
            });
    }
});

router.put('/customers/:customer_id/orders/:order_id', async (req, res) => {
    const response = await handlePutOrder({
        'request': req, 
        'customerId': req.params.customer_id,
        'orderId': req.params.order_id,
        'authHeader': req.get('Authorization'),
        'contentType': req.get('Content-Type')
    });
    
    const authFailed = response.code === 401 ? {"WWW-Authenticate": 'Access to this resource requires authentication'} : undefined

    if(response instanceof Error) {
        res.set(authFailed).status(response.code).json({
            code: response.code,
            message: response.message,
            target: {
                type: response.target,
                name: response.reason
            }
        });
    } else {
        res.status(response.code).json({
            orderDetails: response.updatedOrder
        })
    } 
});

router.delete('/customers/:customer_id/orders/:order_id', (req, res) => {
    const response = handleDeleteOrder({
        'customerId': req.params.customer_id, 
        'orderId': req.params.order_id,
        'authHeader': req.get('Authorization')
    });
    
    const authFailed = response.code === 401 ? {"WWW-Authenticate": 'Access to this resource requires authentication'} : undefined

    if(response instanceof Error) {
        res.set(authFailed).status(response.code).json({
            code: response.code,
            message: response.message,
            target: {
                type: response.target,
                name: response.reason
            }
        });
    } else {
        res.status(response.code).json({});
    }
});

module.exports = router;
