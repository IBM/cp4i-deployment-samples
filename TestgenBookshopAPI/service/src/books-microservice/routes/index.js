const express = require('express');
const router = express.Router();

const {handleGetBook} = require('../handleRequests/Books/handleGet');
const handlePostBook = require('../handleRequests/Books/handlePost');
const handlePutBook = require('../handleRequests/Books/handlePut');
const handleDeleteBook = require('../handleRequests/Books/handleDelete');

router.get('/books/:book_id', async (req, res) => {
    const response = await handleGetBook({
        'bookID': req.params.book_id, 
        'authHeader': req.get('Authorization'),
        'request': req
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
            book: response.book
        })
    }
});

router.put('/books/:book_id', async (req, res) => {
    const response = await handlePutBook({
        'rawRequest': req,
        'bookID': req.params.book_id, 
        'authHeader': req.get('Authorization'),
        'contentType': req.get('Content-Type'),
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
            book: response.book
        })
    } 
});

router.post('/books', async (req, res) => {
    const url = req.protocol + "://" + req.get("host") + req.originalUrl + "/";
    const request = {
        'rawRequest': req, 
        'authHeader': req.get('Authorization'),
        'contentType': req.get('Content-Type'),
        'returnUrl': url
    };
    const response = await handlePostBook(request);
    if(response instanceof Error) {
        const authFailed = response.code === 401 ? {"WWW-Authenticate": 'Access to this resource requires authentication'} : undefined
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
            .set("Location", response.bookLocation)
            .json({
                book: response.book
            })
    }
});

router.delete('/books/:book_id', async (req, res) => {
    const response = await handleDeleteBook({
        'bookID': req.params.book_id, 
        'authHeader': req.get('Authorization'),
        'request': req
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