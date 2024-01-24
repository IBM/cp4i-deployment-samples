const express = require('express')
const router = express.Router()
const RequestError = require('requesterror')

const { postAuthor } = require('../handlers/author')
const { postCategory } = require('../handlers/category')
const { postUsage } = require('../handlers/usage')

const jsonParser = express.json({strict: false})

function contentCheck(req, res, next) {
    if (req.get('Content-Type') && !req.is('application/json')) {
        return next(new RequestError(415, 'unsupported_content_type', 'The specified content type is not supported by the server'))
    }
    if (!req.accepts('application/json')) {
        return next(new RequestError(406, 'unsupported_content_type', 'The requested content type is not supported by the server'))
    }
    return jsonParser(req, res, (err) => {
        if (!err) {
            // request body must be an object
            const body = req.body
            if (body == null || typeof body != 'object' || Array.isArray(body)) {
                err = new RequestError(400, 'invalid_input', 'The request body must be a JSON object')
            }
        }
        return next(err)
    })
}

function methodError(req, res, next) {
    next(new RequestError(405, 'unsupported_method', 'The requested method is not supported on this endpoint', headers = {
        headers: {
            allow: 'POST'
        }
    }))
}

router.route('/services/author')
    .post(contentCheck, postAuthor)
    .all(methodError)

router.route('/services/category')
    .post(contentCheck, postCategory)
    .all(methodError)

router.route('/services/usage')
    .post(contentCheck, postUsage)
    .all(methodError)

module.exports = router
